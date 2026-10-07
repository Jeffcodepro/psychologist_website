module ReusesImageUploads
  extend ActiveSupport::Concern

  included do
    before_validation :clear_requested_images
    before_save :reuse_image_uploads
  end

  private

  def clear_requested_images
    self.class.attachment_reflections.each_key do |name|
      flag = "remove_#{name}"
      public_send("#{name}=", nil) if respond_to?(flag) && ActiveModel::Type::Boolean.new.cast(public_send(flag))
    end
  end

  def reuse_image_uploads
    changes = attachment_changes.values.select do |change|
      change.is_a?(ActiveStorage::Attached::Changes::CreateOne) && change.blob.new_record?
    end
    return if changes.empty?

    owner_id = if is_a?(SiteSetting)
      tenant_id
    elsif is_a?(Section)
      page&.tenant_id
    else
      section&.page&.tenant_id
    end
    return unless owner_id

    reuse = ImageUploadReuse.new(tenant_id: owner_id)
    changes.each do |change|
      original = reuse.find_or_remember(change.blob)
      # Assigning a blob creates only an attachment; it does not re-upload bytes.
      public_send("#{change.name}=", original) unless original.equal?(change.blob)
    end
  rescue ImageUploadReuse::VerificationError => error
    errors.add(:base, error.message)
    throw :abort
  end
end
