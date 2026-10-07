module ImagesHelper
  def saved_image?(attachment)
    attachment&.attached? && attachment.blob.persisted?
  end

  def media_editor_image_url(attachment, record, media = "image")
    return unless saved_image?(attachment)
    if record.remove_media_background?(media) && ImageDelivery.cloudinary?(attachment.blob)
      ImageDelivery.cloudinary_url(attachment.blob, width: 1600, remove_background: true)
    else
      url_for(attachment)
    end
  end

  def display_image_tag(attachment, profile: :content, sizes: "100vw", eager: false, remove_background: false, **options)
    return "".html_safe unless saved_image?(attachment)
    defaults = { loading: eager ? "eager" : "lazy", decoding: "async", fetchpriority: eager ? "high" : "auto" }
    return image_tag(attachment, **defaults.merge(options)) unless attachment.variable?

    # Proxy URLs return the cached derivative directly, avoiding a redirect per image.
    sources = ImageDelivery::WIDTHS.fetch(profile).to_h do |width|
      url = if ImageDelivery.cloudinary?(attachment.blob)
        ImageDelivery.cloudinary_url(attachment.blob, width: width, remove_background: remove_background)
      else
        variant = attachment.variant(ImageDelivery.variant_name(width))
        rails_storage_proxy_path(variant, only_path: true)
      end
      [url, "#{width}w"]
    end
    if remove_background && ImageDelivery.cloudinary?(attachment.blob)
      options[:data] = (options[:data] || {}).merge(controller: "processed-image",
        processed_image_original_value: ImageDelivery.cloudinary_url(attachment.blob, width: 960),
        action: "error->processed-image#retryImage load->processed-image#loaded")
    end
    metadata = attachment.blob.metadata
    if metadata["width"].to_i.positive? && metadata["height"].to_i.positive?
      defaults.merge!(width: metadata["width"], height: metadata["height"])
    end
    image_tag sources.keys[1], **defaults.merge(srcset: sources, sizes: sizes).merge(options)
  end
end
