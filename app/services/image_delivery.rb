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

  def self.configure(attachable, profile)
    WIDTHS.fetch(profile).each do |width|
      attachable.variant variant_name(width), resize_to_limit: [width, nil],
        format: :webp, saver: { quality: 80, strip: true }, preprocessed: true
    end
  end
end
