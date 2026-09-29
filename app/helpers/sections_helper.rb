module SectionsHelper
  FONT_NAMES = FontCatalog::NAMES
  FONT_STACKS = FontCatalog::STACKS

  SHAPE_OPTIONS = [["Retangular", "rectangle"], ["Arredondada", "rounded"], ["Quadrada", "square"],
                   ["Circular", "circle"], ["Oval", "oval"], ["Arco", "arch"]].freeze
  LAYOUT_OPTIONS = [["Texto à esquerda", "text_left"], ["Texto à direita", "text_right"],
                    ["Imagem acima", "media_top"], ["Imagem abaixo", "media_bottom"]].freeze
  SHAPE_RADII = { "rectangle" => "0px", "rounded" => "24px", "square" => "4px", "circle" => "50%",
                  "oval" => "50%", "arch" => "50% 50% 16px 16px" }.freeze

  def section_style_variables(section)
    %w[desktop tablet mobile].flat_map do |device|
      values = {}
      %w[title body].each do |role|
        values["#{role}-font"] = FONT_STACKS.fetch(section.visual_value("#{role}_font_family", device))
        %w[font_weight font_style line_height letter_spacing].each do |property|
          values["#{role}-#{property.tr('_', '-')}"] = "#{section.visual_value("#{role}_#{property}", device)}#{property == 'letter_spacing' ? 'px' : ''}"
        end
        values["#{role}-size"] = "#{section.visual_value("#{role}_font_size", device)}px"
      end
      %w[title body accent background overlay].each do |role|
        values["#{role}-color"] = section.visual_value("#{role}_color", device)
      end
      values["buttons-order"] = { "before_text" => 0, "between_text" => 1, "after_text" => 3 }.fetch(section.visual_value("buttons_position", device))
      values["buttons-align"] = { "left" => "flex-start", "center" => "center", "right" => "flex-end" }.fetch(section.visual_value("buttons_alignment", device))
      values["text-align"] = section.visual_value("text_alignment", device)
      values["title-align"] = section.visual_value("title_alignment", device)
      values["body-align"] = section.visual_value("body_alignment", device)
      values["title-order"] = section.visual_value("text_order", device) == "body_first" ? 2 : 1
      values["body-order"] = section.visual_value("text_order", device) == "body_first" ? 1 : 2
      values["overlay-opacity"] = section.visual_value("banner_overlay", device).to_f / 100
      %w[image banner].each do |media|
        values["#{media}-x"] = "#{section.visual_value("#{media}_position_x", device)}%"
        values["#{media}-y"] = "#{section.visual_value("#{media}_position_y", device)}%"
        values["#{media}-zoom"] = section.visual_value("#{media}_zoom", device)
      end
      shape = section.visual_value("image_shape", device)
      values["image-radius"] = SHAPE_RADII.fetch(shape)
      values["image-ratio"] = %w[square circle].include?(shape) ? "1 / 1" : "4 / 5"
      values["image-width"] = { "small" => "250px", "medium" => "350px", "large" => "460px" }.fetch(section.visual_value("media_size", device))
      layout = section.visual_value("media_layout", device)
      stacked = %w[media_top media_bottom].include?(layout) || device == "mobile"
      values["layout-columns"] = stacked ? "minmax(0, 1fr)" : "minmax(0, 1.15fr) minmax(0, 0.85fr)"
      values["copy-order"] = %w[text_right media_top].include?(layout) ? 2 : 1
      values["media-order"] = %w[text_right media_top].include?(layout) ? 1 : 2
      values["display"] = section.visual_value("visible", device).to_s == "false" ? "none" : "flex"
      values.map { |key, value| "--#{device}-#{key}: #{value}" }
    end.join("; ")
  end

  def card_image_style(item)
    ratio = %w[square circle].include?(item.image_shape) ? "1 / 1" : (%w[oval arch].include?(item.image_shape) ? "4 / 5" : "16 / 10")
    "--card-image-x: #{item.image_position_x}%; --card-image-y: #{item.image_position_y}%; " \
      "--card-image-zoom: #{item.image_zoom}; --card-image-radius: #{SHAPE_RADII.fetch(item.image_shape)}; --card-image-ratio: #{ratio}"
  end
  def media_adjustment_style(record, media = "image")
    return "" unless record.respond_to?(:media_adjustment)
    MediaAdjustable::ADJUSTMENTS.keys.map do |key|
      value = record.media_adjustment(media, key).to_f
      unit = key == "rotation" ? "deg" : (%w[brightness contrast saturation].include?(key) ? "%" : "")
      "--media-#{key.tr('_', '-')}: #{value}#{unit}"
    end.join("; ")
  end

  def section_media_entries(section, role)
    entries = []
    primary = section.public_send(role)
    if primary.attached?
      entries << { attachment: primary, record: section, media: role, primary: true }
    elsif role == "image" && section.use_profile_image? && @site_setting&.profile_image&.attached?
      entries << { attachment: @site_setting.profile_image, record: section, media: role, primary: true }
    end
    section.slides_for(role).each do |slide|
      entries << { attachment: slide.image, record: slide, media: "image", primary: false }
    end
    entries
  end

  def section_media_slide_style(entry, role)
    record = entry.fetch(:record)
    crop = if entry[:primary]
      "--media-x: var(--section-#{role}-x); --media-y: var(--section-#{role}-y); --media-zoom: var(--section-#{role}-zoom)"
    else
      "--media-x: #{record.image_position_x}%; --media-y: #{record.image_position_y}%; --media-zoom: #{record.image_zoom}"
    end
    "#{crop}; #{media_adjustment_style(record, entry.fetch(:media))}"
  end

end
