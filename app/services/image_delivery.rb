# Display derivatives keep the original upload available to the image editor.
class ImageDelivery
  WIDTHS = {
    logo: [128, 256, 512],
    content: [480, 960, 1600],
    banner: [480, 960, 1600, 1920]
  }.transform_values(&:freeze).freeze

  def self.variant_name(width)
    :"display_#{width}"
  end

  def self.cloudinary?(blob)
    blob&.service_name == "cloudinary"
  end

  def self.cloudinary_url(blob, width:)
    blob.service.url(blob.key, filename: blob.filename, content_type: blob.content_type,
      secure: true, sign_url: true, crop: "limit", width: width,
      quality: "auto:good", fetch_format: "auto")
  end

  def self.preprocess?(record, name)
    return false if cloudinary?(record.public_send(name).blob)
    section = record.is_a?(Section) ? record : (record.section if record.respond_to?(:section))
    !section&.published?
  end

  def self.configure(attachable, profile)
    name = attachable.name
    WIDTHS.fetch(profile).each do |width|
      attachable.variant variant_name(width), resize_to_limit: [width, nil],
        format: :webp, saver: { quality: 80, strip: true }, preprocessed: ->(record) { ImageDelivery.preprocess?(record, name) }
    end
  end
end
