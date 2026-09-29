class ContactFormSchema
  TYPES = %w[text textarea email tel select checkbox date].freeze
  DEFAULT_FIELDS = [
    { "key" => "full_name", "label" => "Nome completo", "label_en" => "Full name", "type" => "text", "required" => true, "width" => "full" },
    { "key" => "phone", "label" => "Telefone com DDD", "label_en" => "Phone number", "type" => "tel", "required" => true, "width" => "half" },
    { "key" => "email", "label" => "E-mail", "label_en" => "Email", "type" => "email", "required" => true, "width" => "half" },
    { "key" => "message", "label" => "Conte um pouco sobre o que está acontecendo", "label_en" => "Tell me a little about what is happening", "type" => "textarea", "required" => true, "width" => "full" }
  ].freeze

  def self.valid?(fields)
    fields.is_a?(Array) && fields.size.between?(1, 20) &&
      fields.all? { |f| f.is_a?(Hash) && f["key"].to_s.match?(/\A[a-z][a-z0-9_]{0,49}\z/) && TYPES.include?(f["type"]) &&
        %w[full half].include?(f["width"]) && [true, false].include?(f["required"]) &&
        f["label"].is_a?(String) && f["label"].length.between?(1, 100) && f["label_en"].to_s.length <= 100 &&
        (f["type"] != "select" || (f["options"].is_a?(Array) && f["options"].size.between?(1, 20) && f["options"].all? { |v| v.is_a?(String) && v.length.between?(1, 100) })) } &&
      fields.map { |f| f["key"] }.uniq.length == fields.length
  end

  def self.label(field)
    I18n.locale == :en ? field["label_en"].presence || field["label"] : field["label"]
  end
end
