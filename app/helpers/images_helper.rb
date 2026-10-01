module ImagesHelper
  def display_image_tag(attachment, profile: :content, sizes: "100vw", eager: false, **options)
    defaults = { loading: eager ? "eager" : "lazy", decoding: "async", fetchpriority: eager ? "high" : "auto" }
    return image_tag(attachment, **defaults.merge(options)) unless attachment.variable?

    # Proxy URLs return the cached derivative directly, avoiding a redirect per image.
    sources = ImageDelivery::WIDTHS.fetch(profile).to_h do |width|
      url = if ImageDelivery.cloudinary?(attachment.blob)
        ImageDelivery.cloudinary_url(attachment.blob, width: width)
      else
        variant = attachment.variant(ImageDelivery.variant_name(width))
        rails_storage_proxy_path(variant, only_path: true)
      end
      [url, "#{width}w"]
    end
    metadata = attachment.blob.metadata
    if metadata["width"].to_i.positive? && metadata["height"].to_i.positive?
      defaults.merge!(width: metadata["width"], height: metadata["height"])
    end
    image_tag sources.keys[1], **defaults.merge(srcset: sources, sizes: sizes).merge(options)
  end
end
