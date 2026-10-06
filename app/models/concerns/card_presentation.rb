module CardPresentation
  extend ActiveSupport::Concern

  DEVICES = %w[desktop tablet mobile].freeze
  OPTIONS = {
    "image_layout" => [["Acima", "top"], ["Abaixo", "bottom"], ["À esquerda", "left"], ["À direita", "right"],
      ["Entre título e texto", "between_text"], ["Antes do botão", "before_button"], ["Fundo do card", "background"]],
    "button_alignment" => [["Esquerda", "left"], ["Centro", "center"], ["Direita", "right"]],
    "button_position" => [["Topo", "top"], ["Centro · entre título e texto", "center"], ["Base", "bottom"]]
  }.freeze
  SPACING = {
    "text_padding" => ["Respiro nas laterais do texto", 22],
    "title_body_gap" => ["Entre título e texto", 12],
    "image_text_gap" => ["Entre imagem e conteúdo", 18],
    "button_gap" => ["Respiro junto ao botão", 12]
  }.freeze
  COLOR_FIELDS = %w[overlay_color background_text_color].freeze
  DEFAULTS = { "image_layout" => "top", "button_alignment" => "left", "button_position" => "bottom",
    "overlay_color" => "#0c1b15", "overlay_opacity" => 68, "background_text_color" => "#ffffff" }.merge(SPACING.keys.index_with { nil }).freeze
  PARAMS = DEVICES.index_with { DEFAULTS.keys }.freeze

  included do
    before_validation :compact_card_settings
    validate :validate_card_settings
  end

  def card_value(field, device = "desktop")
    value = card_settings.dig(device, field).presence || card_settings.dig("desktop", field).presence
    valid_card_setting?(field, value) ? value : DEFAULTS.fetch(field)
  end

  private

  def compact_card_settings
    return unless card_settings.is_a?(Hash)
    self.card_settings = card_settings.transform_values do |values|
      values.is_a?(Hash) ? values.reject { |_key, value| value.blank? } : values
    end.reject { |device, values| DEVICES.include?(device) && values == {} }
  end

  def valid_card_setting?(field, value)
    if OPTIONS.key?(field)
      OPTIONS.fetch(field).any? { |_label, option| option == value }
    elsif COLOR_FIELDS.include?(field)
      value.is_a?(String) && value.match?(/\A#[0-9a-fA-F]{6}\z/)
    elsif SPACING.key?(field)
      number = Float(value, exception: false)
      number && (0..40).cover?(number)
    elsif field == "overlay_opacity"
      number = Float(value, exception: false)
      number && (0..100).cover?(number)
    else
      false
    end
  end

  def validate_card_settings
    valid = card_settings.is_a?(Hash) && card_settings.all? do |device, values|
      DEVICES.include?(device) && values.is_a?(Hash) && values.all? do |field, value|
        valid_card_setting?(field, value)
      end
    end
    errors.add(:card_settings, "composição inválida") unless valid
  end
end
