module VideoMedia
  extend ActiveSupport::Concern
  SOURCES = %w[image youtube upload].freeze
  TYPES = %w[video/mp4 video/webm].freeze
  MAX_SIZE = 20.megabytes
  DEFAULTS = { "source" => "image", "youtube_url" => "", "fit" => "contain", "zoom" => "1", "x" => "50", "y" => "50" }.freeze
  FRAME_KEYS = %w[fit zoom x y].freeze
  FIELDS = DEFAULTS.keys + [{ tablet: FRAME_KEYS, mobile: FRAME_KEYS }]
  PARAMS = { image: FIELDS, banner: FIELDS }.freeze

  included do
    has_one_attached :video
    attr_accessor :remove_video
    before_validation :remove_requested_videos
    validate :validate_video_media
  end

  def video_roles
    is_a?(Section) ? %w[image banner] : %w[image]
  end

  def media_video_attachment(role = "image")
    public_send(role == "banner" ? :banner_video : :video)
  end

  def video_value(role, key, device = "desktop")
    values = video_settings.is_a?(Hash) ? video_settings.fetch(role.to_s, {}) : {}
    values = {} unless values.is_a?(Hash)
    overrides = values[device.to_s]
    override = overrides[key.to_s] if device.to_s != "desktop" && overrides.is_a?(Hash)
    override.presence || values[key.to_s].presence || DEFAULTS.fetch(key.to_s)
  end

  def video_source?(role = "image")
    video_value(role, "source") != "image"
  end

  def youtube_id(role = "image")
    YoutubeVideo.id(video_value(role, "youtube_url"))
  end

  def video_available?(role = "image")
    case video_value(role, "source")
    when "youtube" then youtube_id(role).present?
    when "upload" then media_video_attachment(role).attached? && media_video_attachment(role).blob.persisted?
    else false
    end
  end

  private

  def remove_requested_videos
    video_roles.each do |role|
      flag = role == "banner" ? :remove_banner_video : :remove_video
      next unless ActiveModel::Type::Boolean.new.cast(public_send(flag))
      public_send("#{role == 'banner' ? 'banner_video' : 'video'}=", nil)
      self.video_settings = video_settings.deep_merge(role => { "source" => "image" })
    end
  end

  def validate_video_media
    unless video_settings.is_a?(Hash) && (video_settings.keys - video_roles).empty?
      errors.add(:base, "Configuração de vídeo inválida.")
      return
    end
    video_roles.each do |role|
      values = video_settings.fetch(role, {})
      unless values.is_a?(Hash) && (values.keys - DEFAULTS.keys - %w[tablet mobile]).empty?
        errors.add(:base, "Configuração de vídeo inválida.")
        next
      end
      source = video_value(role, "source")
      errors.add(:base, "Escolha imagem, YouTube ou arquivo de vídeo.") unless SOURCES.include?(source)
      errors.add(:base, "Cole um link válido de vídeo do YouTube.") if source == "youtube" && youtube_id(role).blank?
      %w[desktop tablet mobile].each do |device|
        overrides = values.fetch(device, {})
        unless overrides.is_a?(Hash) && (overrides.keys - FRAME_KEYS).empty?
          errors.add(:base, "Enquadramento por tela inválido.")
          next
        end
        errors.add(:base, "Escolha como encaixar o vídeo.") unless %w[contain cover].include?(video_value(role, "fit", device))
        { "zoom" => 0.25..3, "x" => 0..100, "y" => 0..100 }.each do |key, range|
          number = Float(video_value(role, key, device), exception: false)
          errors.add(:base, "Enquadramento do vídeo inválido.") unless number && range.cover?(number)
        end
      end
      attachment = media_video_attachment(role)
      errors.add(:base, "Selecione um vídeo MP4 ou WebM.") if source == "upload" && !attachment.attached?
      next unless attachment.attached?
      errors.add(:base, "Use vídeo MP4 ou WebM de até 20 MB.") unless TYPES.include?(attachment.blob.content_type) && attachment.blob.byte_size <= MAX_SIZE
    end
  end
end
