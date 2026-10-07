# Reuse originals within one site only. A publication or crop never uploads a file.
class ImageUploadReuse
  class VerificationError < StandardError; end

  class Context < ActiveSupport::CurrentAttributes
    attribute :tenant_id, :candidates
  end

  def self.blobs_for(tenant_id)
    sections = Section.where(page_id: Page.where(tenant_id: tenant_id).select(:id)).select(:id)
    attachments = ActiveStorage::Attachment.where(record_type: "SiteSetting", record_id: SiteSetting.where(tenant_id: tenant_id).select(:id))
      .or(ActiveStorage::Attachment.where(record_type: "Section", record_id: sections))
      .or(ActiveStorage::Attachment.where(record_type: "SectionItem", record_id: SectionItem.where(section_id: sections).select(:id)))
      .or(ActiveStorage::Attachment.where(record_type: "SectionSlide", record_id: SectionSlide.where(section_id: sections).select(:id)))
    ActiveStorage::Blob.where(id: attachments.select(:blob_id))
  end

  # A session lock spans after_commit uploads as well as the save. Two requests
  # uploading the same new image cannot both create an original for this site.
  def self.within_site(tenant_id)
    lock_key = Digest::SHA256.hexdigest("cms-image-upload:#{tenant_id}")[0, 15].to_i(16)
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute("SELECT pg_advisory_lock(#{lock_key})")
      begin
        Context.set(tenant_id: tenant_id, candidates: {}) { yield }
      ensure
        connection.execute("SELECT pg_advisory_unlock(#{lock_key})")
      end
    end
  end

  def initialize(tenant_id:)
    @tenant_id = tenant_id
    @candidates = Context.tenant_id == tenant_id ? Context.candidates : {}
  end

  def find_or_remember(blob)
    key = [blob.service_name, blob.checksum, blob.byte_size, blob.content_type]
    return blob if blob.checksum.blank?
    return @candidates[key] if @candidates.key?(key)
    existing = self.class.blobs_for(@tenant_id).find_by(
      service_name: blob.service_name, checksum: blob.checksum,
      byte_size: blob.byte_size, content_type: blob.content_type
    )
    # A previous interrupted upload can have a DB row without a remote file.
    # Re-selecting the file must recover that case instead of reusing a broken link.
    existing = nil if existing && !original_available?(existing)
    @candidates[key] = existing || blob
  end

  private

  def original_available?(original)
    original.service.exist?(original.key)
  rescue StandardError => error
    Rails.logger.warn("Image reuse verification failed: #{error.class.name}")
    raise VerificationError, "Não foi possível conferir a imagem já salva. Tente novamente; nenhum novo arquivo foi enviado."
  end
end
