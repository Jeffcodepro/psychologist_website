module SectionSpacingHelper
  # Offset the existing gap so older pages retain their original spacing. The
  # adjacent element follows visual order, including reversed text and inline media.
  def section_flow_spacing(section, device, images_present:, cards_present:)
    layout = section_media_layout(section, device)
    inline_media = images_present && %w[media_between media_before_buttons].include?(layout)
    placement = section.visual_value("buttons_position", device)
    collection_buttons = %w[before_cards after_cards].include?(placement)
    has_buttons = section.action_buttons.any?
    title_first = section.visual_value("text_order", device) != "body_first"
    button_order = { "before_text" => 0, "between_text" => 3 }.fetch(placement, 6)
    nodes = []
    nodes << ["title", title_first ? 2 : 4] if section.localized_title.present?
    nodes << ["body", title_first ? 4 : 2] if section.localized_body.present?
    nodes << ["extra", 5] if %w[faq gallery].include?(section.section_type)
    nodes << ["buttons", button_order] if has_buttons && !collection_buttons
    nodes << ["media", layout == "media_between" ? 3 : button_order - 1] if inline_media
    ordered = nodes.each_with_index.sort_by { |(_, order), index| [order, index] }.map { |(key, _), _| key }
    base = section.visual_value("content_gap", device).to_f
    values = %w[title body buttons media extra].to_h { |key| ["copy-#{key}-offset", "0px"] }
    ordered.each_cons(2) do |previous, current|
      field = if [previous, current].include?("buttons") then "buttons_gap"
        elsif [previous, current].include?("media") then "image_text_gap"
        else "title_body_gap"
        end
      values["copy-#{current}-offset"] = "#{section.visual_value(field, device).to_f - base}px"
    end

    collection = []
    has_content = section.localized_title.present? || section.localized_body.present? || images_present || has_buttons || %w[faq gallery contact].include?(section.section_type)
    cards_order = section.cards_placement == "before" ? 10 : 30
    collection << ["content", 20] if has_content
    collection << ["cards", cards_order] if cards_present
    collection << ["buttons", cards_order + (placement == "before_cards" ? -1 : 1)] if has_buttons && collection_buttons
    %w[content cards buttons].each { |key| values["collection-#{key}-offset"] = "0px" }
    collection.sort_by(&:last).map(&:first).each_cons(2) do |previous, current|
      field = [previous, current].include?("buttons") ? "buttons_gap" : "cards_content_gap"
      values["collection-#{current}-offset"] = "#{section.visual_value(field, device).to_f - section.visual_value('column_gap', device).to_f}px"
    end
    values
  end
end
