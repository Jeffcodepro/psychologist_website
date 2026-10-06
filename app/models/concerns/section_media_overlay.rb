module SectionMediaOverlay
  extend ActiveSupport::Concern

  COLOR_FIELDS = %w[banner_overlay_color image_overlay_color].freeze
  NUMBER_FIELDS = %w[banner_overlay_opacity image_overlay_opacity].index_with { 0..100 }.freeze
  FIELDS = (COLOR_FIELDS + NUMBER_FIELDS.keys).freeze

  included do
    store_accessor :layout_settings, *FIELDS
    validates(*COLOR_FIELDS, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true)
    validates(*NUMBER_FIELDS.keys, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_blank: true)
  end

  def media_overlay_value(role, property, device = "desktop")
    field = "#{role}_overlay_#{property}"
    raise ArgumentError, "Unknown media overlay field" unless FIELDS.include?(field)

    override = responsive_settings.dig(device.to_s, field)
    return override unless override.blank?
    base = public_send(field)
    return base unless base.blank?

    # Preserve the appearance of published sections that used the shared overlay.
    return visual_value("overlay_color", device) if property == "color"
    background = role == "banner" ? visual_value("banner_layout", device) == "background" : visual_value("media_layout", device) == "media_background"
    background ? visual_value("banner_overlay", device) : 0
  end
end
