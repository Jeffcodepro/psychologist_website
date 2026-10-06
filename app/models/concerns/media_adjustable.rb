module MediaAdjustable
  extend ActiveSupport::Concern

  ADJUSTMENTS = { "rotation" => -180..180, "brightness" => 0..200,
                  "contrast" => 0..200, "saturation" => 0..200,
                  "flip_x" => -1..1, "flip_y" => -1..1,
                  "shadow" => 0..60, "remove_background" => 0..1 }.freeze
  ENUMS = { "fit" => %w[cover contain] }.freeze
  DEFAULTS = { "rotation" => 0, "brightness" => 100, "contrast" => 100,
               "saturation" => 100, "flip_x" => 1, "flip_y" => 1,
               "shadow" => 0, "remove_background" => 0, "fit" => "cover" }.freeze
  PARAMS = { image: DEFAULTS.keys, banner: DEFAULTS.keys }.freeze

  included do
    validate :validate_media_adjustments
  end

  def media_adjustment(media, key)
    media_adjustments.dig(media.to_s, key.to_s).presence || DEFAULTS.fetch(key.to_s)
  end

  def remove_media_background?(media = "image")
    media_adjustment(media, "remove_background").to_i == 1
  end

  private

  def validate_media_adjustments
    unless media_adjustments.is_a?(Hash)
      errors.add(:media_adjustments, "ajustes inválidos")
      return
    end
    media_adjustments.each do |media, values|
      unless %w[image banner].include?(media) && values.is_a?(Hash)
        errors.add(:media_adjustments, "imagem inválida")
        next
      end
      values.each do |key, value|
        if ENUMS.key?(key)
          valid = ENUMS[key].include?(value)
        else
          number = Float(value, exception: false)
          valid = number && ADJUSTMENTS[key]&.cover?(number)
          valid &&= [-1, 1].include?(number) if key.start_with?("flip")
          valid &&= [0, 1].include?(number) if key == "remove_background"
        end
        errors.add(:media_adjustments, "#{key} inválido") unless valid
      end
    end
  end
end
