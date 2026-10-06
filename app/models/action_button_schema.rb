class ActionButtonSchema
  ACTIONS = { "Contato" => "contact", "Outra página" => "page", "Seção de uma página" => "section", "Trecho desta página" => "anchor", "Link externo" => "url", "WhatsApp" => "whatsapp", "E-mail" => "email", "Telefone" => "phone" }.freeze

  def self.valid?(buttons, tenant:)
    buttons.is_a?(Array) && buttons.size <= 8 && buttons.all? do |button|
      button.is_a?(Hash) && button['label'].is_a?(String) && button['label'].length.between?(1, 80) &&
        button['label_en'].to_s.length <= 80 && valid_appearance?(button) &&
        valid_destination?(button['action'], button['value'].to_s, tenant)
    end
  end

  def self.valid_appearance?(button)
    %w[primary secondary custom].include?(button['style']) &&
      (button['size'].blank? || %w[small medium large].include?(button['size'])) &&
      (button['shape'].blank? || %w[pill rounded square].include?(button['shape'])) &&
      %w[background_color text_color].all? { |key| button[key].blank? || button[key].is_a?(String) && button[key].match?(/\A#[0-9a-fA-F]{6}\z/) } &&
      (button['style'] != 'custom' || %w[background_color text_color].all? { |key| button[key].present? })
  end

  def self.valid_destination?(action, value, tenant)
    return false if value.length > 1000 || value.match?(/[\r\n]/)
    case action
    when 'contact' then true
    when 'page' then value.match?(/\A\d+\z/) && tenant&.pages&.exists?(id: value)
    when 'section' then value.match?(/\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/) && tenant&.sections&.draft&.exists?(navigation_key: value)
    when 'anchor' then value.match?(/\A#?[a-zA-Z][a-zA-Z0-9_-]{0,99}\z/)
    when 'email' then value.match?(URI::MailTo::EMAIL_REGEXP)
    when 'phone', 'whatsapp' then value.match?(/\A\+?[\d\s().-]+\z/) && value.gsub(/\D/, '').length.between?(8, 15)
    when 'url'
      uri = URI.parse(value)
      %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil?
    else false
    end
  rescue URI::InvalidURIError
    false
  end
end
