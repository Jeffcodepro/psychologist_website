module VideoMediaHelper
  def video_file_url(attachment)
    return unless attachment.attached? && attachment.blob.persisted?
    blob = attachment.blob
    if ImageDelivery.cloudinary?(blob)
      blob.service.url(blob.key, filename: blob.filename, content_type: blob.content_type, secure: true, sign_url: true)
    else
      rails_blob_path(blob, disposition: "inline", only_path: true)
    end
  end

  def video_frame_style(record, role = "image")
    %w[desktop tablet mobile].flat_map do |device|
      VideoMedia::FRAME_KEYS.map do |key|
        value = record.video_value(role, key, device)
        unit = %w[x y].include?(key) ? "%" : ""
        "--video-#{device}-#{key}: #{value}#{unit}"
      end
    end.join("; ")
  end
end
