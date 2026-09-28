module ImageAttachments
  extend ActiveSupport::Concern

  class_methods do
    def validates_image_attachments(*names)
      validate do
        names.each do |name|
          attachment = public_send(name)
          next unless attachment.attached?
          errors.add(name, "deve ser JPG, PNG ou WebP") unless %w[image/jpeg image/png image/webp].include?(attachment.blob.content_type)
          errors.add(name, "deve ter no máximo 10 MB") if attachment.blob.byte_size > 10.megabytes
        end
      end
    end
  end
end
