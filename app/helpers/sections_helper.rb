module SectionsHelper
  FONT_NAMES = FontCatalog::NAMES
  FONT_STACKS = FontCatalog::STACKS

  SHAPE_OPTIONS = [["Retangular", "rectangle"], ["Arredondada", "rounded"], ["Quadrada", "square"],
                   ["Circular", "circle"], ["Oval", "oval"], ["Arco", "arch"], ["Sem moldura · foto recortada", "cutout"]].freeze
  LAYOUT_OPTIONS = [["Texto à esquerda", "text_left"], ["Texto à direita", "text_right"],
                    ["Imagem acima", "media_top"], ["Imagem abaixo", "media_bottom"],
                    ["Entre título e parágrafo", "media_between"], ["Entre parágrafo e botões", "media_before_buttons"],
                    ["Imagem de fundo", "media_background"]].freeze
  SHAPE_RADII = { "rectangle" => "0px", "rounded" => "24px", "square" => "4px", "circle" => "50%",
                  "oval" => "50%", "arch" => "50% 50% 16px 16px", "cutout" => "0px" }.freeze

  def section_media_layout(section, device)
    layout = section.visual_value("media_layout", device)
    # Keep the established stacked mobile default, but honour an explicit mobile choice.
    if device == "mobile" && section.responsive_settings.dig(device, "media_layout").blank?
      return "media_top" if layout == "text_right"
      return "media_bottom" if layout == "text_left"
    end
    layout
  end

  def section_style_variables(section)
    images_present = section_media_entries(section, "image").any?
    cards_present = section.visible_items("card").any?
    %w[desktop tablet mobile].flat_map do |device|
      values = section_flow_spacing(section, device, images_present: images_present, cards_present: cards_present)
      SectionLayout::SPACING.each_key { |field| values[field.tr("_", "-")] = "#{section.visual_value(field, device)}px" }
      form_position = section.visual_value("form_position", device)
      if device == "mobile" && section.responsive_settings.dig(device, "form_position").blank? && %w[left right].include?(form_position)
        form_position = "after_text"
      end
      values["contact-columns"] = %w[left right].include?(form_position) ? "repeat(2, minmax(0, 1fr))" : "minmax(0, 1fr)"
      values["form-vertical-align"] = { "top" => "start", "center" => "center", "bottom" => "end" }.fetch(section.visual_value("form_vertical_alignment", device))
      values["form-order"] = %w[left before_text].include?(form_position) ? 0 : 2
      values["form-align"] = { "left" => "start", "center" => "center", "right" => "end" }.fetch(section.visual_value("form_alignment", device))
      values["form-width"] = { "compact" => "480px", "medium" => "640px", "wide" => "860px", "full" => "100%" }.fetch(section.visual_value("form_width", device))
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
      buttons_position = section.visual_value("buttons_position", device)
      collection_buttons = %w[before_cards after_cards].include?(buttons_position)
      cards_order = section.cards_placement == "before" ? 10 : 30
      values["cards-order"] = cards_order
      values["buttons-collection-order"] = cards_order + (buttons_position == "before_cards" ? -1 : 1)
      values["buttons-inline-display"] = collection_buttons ? "none" : "flex"
      values["buttons-collection-display"] = collection_buttons ? "flex" : "none"
      values["buttons-order"] = { "before_text" => 0, "between_text" => 1 }.fetch(buttons_position, 3)
      values["buttons-inline-order"] = { "before_text" => 0, "between_text" => 3 }.fetch(buttons_position, 6)
      values["buttons-align"] = { "left" => "flex-start", "center" => "center", "right" => "flex-end" }.fetch(section.visual_value("buttons_alignment", device))
      values["text-align"] = section.visual_value("text_alignment", device)
      values["title-align"] = section.visual_value("title_alignment", device)
      values["body-align"] = section.visual_value("body_alignment", device)
      values["title-order"] = section.visual_value("text_order", device) == "body_first" ? 2 : 1
      values["body-order"] = section.visual_value("text_order", device) == "body_first" ? 1 : 2
      values["overlay-opacity"] = section.visual_value("banner_overlay", device).to_f / 100
      %w[image banner].each do |media|
        values["#{media}-tint-color"] = section.media_overlay_value(media, "color", device)
        values["#{media}-tint-opacity"] = section.media_overlay_value(media, "opacity", device).to_f / 100
        values["#{media}-x"] = "#{section.visual_value("#{media}_position_x", device)}%"
        values["#{media}-y"] = "#{section.visual_value("#{media}_position_y", device)}%"
        values["#{media}-zoom"] = section.visual_value("#{media}_zoom", device)
      end
      shape = section.visual_value("image_shape", device)
      values["image-radius"] = SHAPE_RADII.fetch(shape)
      values["image-overflow"] = shape == "cutout" ? "visible" : "hidden"
      values["image-tint-display"] = shape == "cutout" ? "none" : "block"
      values["image-ratio"] = %w[square circle].include?(shape) ? "1 / 1" : "4 / 5"
      values["image-width"] = { "small" => "250px", "medium" => "350px", "large" => "460px" }.fetch(section.visual_value("media_size", device))
      layout = section_media_layout(section, device)
      stacked = !%w[text_left text_right].include?(layout)
      values["layout-columns"] = stacked ? "minmax(0, 1fr)" : "minmax(0, 1.15fr) minmax(0, 0.85fr)"
      values["copy-order"] = %w[text_right media_top].include?(layout) ? 2 : 1
      values["media-order"] = %w[text_right media_top].include?(layout) ? 1 : 2
      values["display"] = section.visual_value("visible", device).to_s == "false" ? "none" : "flex"
      values.map { |key, value| "--#{device}-#{key}: #{value}" }
    end.join("; ")
  end

  def card_overlay_style(item)
    CardPresentation::DEVICES.flat_map do |device|
      ["--card-#{device}-overlay-color: #{item.card_value('overlay_color', device)}",
       "--card-#{device}-overlay-opacity: #{item.card_value('overlay_opacity', device).to_f / 100}",
       "--card-#{device}-background-text-color: #{item.card_value('background_text_color', device)}"] +
        CardPresentation::SPACING.keys.filter_map do |field|
          value = item.card_value(field, device)
          "--card-#{device}-#{field.tr('_', '-')}: #{value}px" unless value.nil?
        end
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
    end.join("; ") + "; --media-fit: #{record.media_adjustment(media, 'fit')}; --media-shadow-opacity: #{record.media_adjustment(media, 'shadow').to_f / 100}"
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
