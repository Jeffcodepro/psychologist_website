# Move each original independently. The source is kept for recovery and the
# database switches only after the destination passes checksum verification.
class MediaStorageMigration
  RECORD_TYPES = %w[SiteSetting Section SectionItem SectionSlide].freeze

  def self.originals
    ActiveStorage::Blob.joins(:attachments).where(active_storage_attachments: { record_type: RECORD_TYPES }).distinct
  end

  def initialize(source:, target:)
    @source, @target = source, target
    @destination = ActiveStorage::Blob.services.fetch(target)
  end

  def move(blob)
    blob.with_lock do
      return :skipped unless blob.service_name == @source
      unless @destination.exist?(blob.key)
        blob.open do |file|
          @destination.upload(blob.key, file, checksum: blob.checksum, content_type: blob.content_type, filename: blob.filename)
        end
      end
      @destination.open(blob.key, checksum: blob.checksum, verify: true) { |_file| }
      blob.update!(service_name: @target)
    end
    :moved
  end
end
