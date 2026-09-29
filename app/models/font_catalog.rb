class FontCatalog
  NAMES = {
    "playfair" => "Playfair Display", "dm_sans" => "DM Sans",
    "cormorant" => "Cormorant Garamond", "lora" => "Lora",
    "montserrat" => "Montserrat", "libre_baskerville" => "Libre Baskerville",
    "merriweather" => "Merriweather", "inter" => "Inter", "manrope" => "Manrope",
    "source_sans" => "Source Sans 3", "nunito_sans" => "Nunito Sans",
    "poppins" => "Poppins", "raleway" => "Raleway", "roboto" => "Roboto",
    "open_sans" => "Open Sans", "pt_serif" => "PT Serif", "eb_garamond" => "EB Garamond",
    "dm_serif" => "DM Serif Display", "ubuntu" => "Ubuntu",
    "outfit" => "Outfit", "sora" => "Sora", "quicksand" => "Quicksand",
    "crimson_pro" => "Crimson Pro", "fraunces" => "Fraunces", "caveat" => "Caveat",
    "dancing_script" => "Dancing Script", "source_code" => "Source Code Pro"
  }.freeze
  SERIFS = %w[playfair cormorant lora libre_baskerville merriweather pt_serif eb_garamond dm_serif crimson_pro fraunces].freeze
  STACKS = NAMES.to_h { |key, name| [key, "\"#{name}\", #{SERIFS.include?(key) ? 'serif' : (key == 'source_code' ? 'monospace' : (%w[caveat dancing_script].include?(key) ? 'cursive' : 'sans-serif'))}"] }.freeze
end
