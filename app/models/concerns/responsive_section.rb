module ResponsiveSection
  extend ActiveSupport::Concern

  DEVICES = %w[tablet mobile].freeze
  ENUM_FIELDS = SectionLayout::FORM_OPTIONS.transform_values { |(_, options)| options.map(&:last) }.merge({
    "buttons_position" => SectionLayout::BUTTON_POSITIONS.map(&:last),
    "buttons_alignment" => %w[left center right],
    "media_layout" => %w[text_left text_right media_top media_bottom media_between media_before_buttons media_background],
    "media_size" => %w[small medium large],
    "image_shape" => %w[rectangle rounded square circle oval arch cutout],
    "banner_layout" => %w[top background bottom],
    "text_alignment" => %w[left center right],
    "title_alignment" => %w[left center right],
    "body_alignment" => %w[left center right],
    "text_order" => %w[title_first body_first],
    "title_font_style" => %w[normal italic], "body_font_style" => %w[normal italic],
    "title_font_weight" => %w[300 400 500 600 700 800], "body_font_weight" => %w[300 400 500 600 700 800],
    "visible" => %w[true false]
  }).freeze
  NUMBER_FIELDS = SectionLayout::SPACING.transform_values { |(_, _, range)| range }.merge(SectionMediaOverlay::NUMBER_FIELDS).merge({
    "title_line_height" => 1..2.5, "body_line_height" => 1..2.5,
    "title_letter_spacing" => -1..4, "body_letter_spacing" => -1..4,
    "title_font_size" => 10..120, "body_font_size" => 10..120,
    "image_position_x" => 0..100, "image_position_y" => 0..100,
    "banner_position_x" => 0..100, "banner_position_y" => 0..100,
    "image_zoom" => 0.25..3, "banner_zoom" => 0.25..3, "banner_overlay" => 0..90
  }).freeze
  FONT_FIELDS = %w[title_font_family body_font_family].freeze
  COLOR_FIELDS = (%w[title_color body_color background_color accent_color overlay_color] + SectionMediaOverlay::COLOR_FIELDS).freeze
  FIELDS = (ENUM_FIELDS.keys + NUMBER_FIELDS.keys + FONT_FIELDS + COLOR_FIELDS).freeze

  included do
    before_validation :compact_responsive_settings
    validate :validate_responsive_settings
  end

  # Each device inherits the base independently; a mobile edit never changes tablet.
  def visual_value(field, device = "desktop")
    override = responsive_settings.dig(device.to_s, field.to_s)
    return override unless override.nil? || override == ""

    if %w[title_font_size body_font_size].include?(field.to_s)
      return public_send("#{field}_#{device.to_s == 'mobile' ? 'mobile' : 'desktop'}")
    end

    if %w[title_alignment body_alignment].include?(field.to_s) && public_send(field).blank?
      return visual_value("text_alignment", device)
    end

    return visible? if field.to_s == "visible"

    if SectionLayout::INHERITED_SPACING.key?(field.to_s)
      base = public_send(field).presence
      return base if base
      fallback = SectionLayout::INHERITED_SPACING.fetch(field.to_s)
      fallback = "content_gap" if field.to_s == "image_text_gap" && %w[media_between media_before_buttons].include?(visual_value("media_layout", device))
      fallback = "column_gap" if field.to_s == "buttons_gap" && %w[before_cards after_cards].include?(visual_value("buttons_position", device))
      return visual_value(fallback, device)
    end

    effective = "effective_#{field}"
    respond_to?(effective) ? public_send(effective) : public_send(field)
  end

  private

  def compact_responsive_settings
    return unless responsive_settings.is_a?(Hash)

    self.responsive_settings = responsive_settings.transform_values do |settings|
      settings.is_a?(Hash) ? settings.reject { |_key, value| value.nil? || value == "" } : settings
    end.reject { |_device, settings| settings == {} }
  end

  def validate_responsive_settings
    unless responsive_settings.is_a?(Hash)
      errors.add(:responsive_settings, "deve conter ajustes por tela")
      return
    end

    responsive_settings.each do |device, settings|
      unless DEVICES.include?(device) && settings.is_a?(Hash)
        errors.add(:responsive_settings, "tela inválida")
        next
      end

      settings.each do |field, value|
        valid = if ENUM_FIELDS.key?(field)
          ENUM_FIELDS.fetch(field).include?(value.to_s)
        elsif NUMBER_FIELDS.key?(field)
          number = Float(value, exception: false)
          number && NUMBER_FIELDS.fetch(field).cover?(number)
        elsif FONT_FIELDS.include?(field)
          Section::FONT_FAMILIES.include?(value)
        elsif COLOR_FIELDS.include?(field)
          value.is_a?(String) && value.match?(/\A#[0-9a-fA-F]{6}\z/)
        else
          false
        end
        errors.add(:responsive_settings, "#{device}: #{field} inválido") unless valid
      end
    end
  end
end
