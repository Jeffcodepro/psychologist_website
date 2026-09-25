module SectionsHelper
  FONT_STACKS = {
    "playfair" => '"Playfair Display", serif',
    "dm_sans" => '"DM Sans", sans-serif',
    "cormorant" => '"Cormorant Garamond", serif',
    "lora" => '"Lora", serif',
    "montserrat" => '"Montserrat", sans-serif'
  }.freeze

  def section_style_variables(section)
    title_font =
      FONT_STACKS.fetch(
        section.title_font_family,
        FONT_STACKS["playfair"]
      )

    body_font =
      FONT_STACKS.fetch(
        section.body_font_family,
        FONT_STACKS["dm_sans"]
      )

    [
      "--section-title-font: #{title_font}",
      "--section-body-font: #{body_font}",

      "--section-title-size-desktop: #{section.title_font_size_desktop}px",
      "--section-title-size-mobile: #{section.title_font_size_mobile}px",

      "--section-body-size-desktop: #{section.body_font_size_desktop}px",
      "--section-body-size-mobile: #{section.body_font_size_mobile}px",

      "--section-text-align: #{section.text_alignment}"
    ].join("; ")
  end
end
