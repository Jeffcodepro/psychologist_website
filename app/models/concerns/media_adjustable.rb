module MediaAdjustable
  extend ActiveSupport::Concern

  ADJUSTMENTS = { "rotation" => -180..180, "brightness" => 0..200,
                  "contrast" => 0..200, "saturation" => 0..200,
                  "flip_x" => -1..1, "flip_y" => -1..1 }.freeze
  PARAMS = { image: ADJUSTMENTS.keys, banner: ADJUSTMENTS.keys }.freeze

  included do
    validate :validate_media_adjustments
  end

  def media_adjustment(media, key)
    media_adjustments.dig(media.to_s, key.to_s).presence ||
      (key.to_s.start_with?("flip") ? 1 : (key.to_s == "rotation" ? 0 : 100))
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
        number = Float(value, exception: false)
        valid = number && ADJUSTMENTS[key]&.cover?(number)
        valid &&= [-1, 1].include?(number) if key.start_with?("flip")
        errors.add(:media_adjustments, "#{key} inválido") unless valid
      end
    end
  end
end
