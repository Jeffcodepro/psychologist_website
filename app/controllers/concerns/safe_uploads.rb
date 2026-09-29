module SafeUploads
  extend ActiveSupport::Concern
  UPLOAD_FIELDS = %w[image banner logo profile_image seo_image].freeze
  ALLOWED_TYPES = %w[image/jpeg image/png image/webp].freeze

  included do
    before_action :validate_upload_inputs!, if: -> { %w[create update].include?(action_name) }
  end

  private

  # The CMS sends multipart files, never existing signed blob IDs or remote URLs.
  # This also prevents attaching an image belonging to a different tenant.
  def validate_upload_inputs!
    inspect_uploads(params)
  rescue ActionController::BadRequest
    render plain: "Imagem inválida. Envie JPG, PNG ou WebP de até 10 MB.", status: :unprocessable_entity
  end

  def inspect_uploads(values)
    values.each_pair do |key, value|
      next if %w[media_adjustments responsive_settings].include?(key.to_s)
      if UPLOAD_FIELDS.include?(key.to_s) && value.present?
        raise ActionController::BadRequest unless value.is_a?(ActionDispatch::Http::UploadedFile) && value.size <= 10.megabytes
        type = Marcel::MimeType.for(value.tempfile)
        value.tempfile.rewind
        raise ActionController::BadRequest unless ALLOWED_TYPES.include?(type)
        value.content_type = type
      elsif value.respond_to?(:each_pair)
        inspect_uploads(value)
      elsif value.is_a?(Array)
        value.each { |item| inspect_uploads(item) if item.respond_to?(:each_pair) }
      end
    end
  end
end
