module SafeUploads
  extend ActiveSupport::Concern
  UPLOAD_FIELDS = %w[image banner logo profile_image seo_image].freeze
  VIDEO_FIELDS = %w[video banner_video].freeze
  ALLOWED_TYPES = %w[image/jpeg image/png image/webp].freeze

  included do
    before_action :validate_upload_inputs!, if: -> { %w[create update].include?(action_name) }
    around_action :reuse_uploads_within_site, if: -> { @contains_image_upload }
  end

  private

  # The CMS sends multipart files, never existing signed blob IDs or remote URLs.
  # This also prevents attaching an image belonging to a different tenant.
  def validate_upload_inputs!
    @upload_bytes = 0
    inspect_uploads(params)
  rescue ActionController::BadRequest
    render plain: "Arquivo inválido. Envie JPG, PNG ou WebP de até 10 MB, ou vídeo MP4/WebM de até 20 MB. O total por salvamento deve ser de até 60 MB.", status: :unprocessable_entity
  end

  def reuse_uploads_within_site(&action)
    ImageUploadReuse.within_site(current_tenant.id, &action)
  end

  def inspect_uploads(values)
    values.each_pair do |key, value|
      next if %w[media_adjustments responsive_settings video_settings].include?(key.to_s)
      if (UPLOAD_FIELDS + VIDEO_FIELDS).include?(key.to_s) && value.present?
        video = VIDEO_FIELDS.include?(key.to_s)
        limit = video ? VideoMedia::MAX_SIZE : 10.megabytes
        raise ActionController::BadRequest unless value.is_a?(ActionDispatch::Http::UploadedFile) && value.size <= limit
        @upload_bytes += value.size
        raise ActionController::BadRequest if @upload_bytes > 60.megabytes
        type = Marcel::MimeType.for(value.tempfile)
        value.tempfile.rewind
        raise ActionController::BadRequest unless (video ? VideoMedia::TYPES : ALLOWED_TYPES).include?(type)
        value.content_type = type
        @contains_image_upload = true
      elsif value.respond_to?(:each_pair)
        inspect_uploads(value)
      elsif value.is_a?(Array)
        value.each { |item| inspect_uploads(item) if item.respond_to?(:each_pair) }
      end
    end
  end
end
