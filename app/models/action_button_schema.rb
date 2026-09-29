class ActionButtonSchema
  ACTIONS = { "Contato" => "contact", "Outra página" => "page", "Trecho desta página" => "anchor", "Link externo" => "url", "WhatsApp" => "whatsapp", "E-mail" => "email", "Telefone" => "phone" }.freeze

  def self.valid?(buttons, tenant:)
    buttons.is_a?(Array) && buttons.size <= 8 && buttons.all? do |button|
      button.is_a?(Hash) && button['label'].is_a?(String) && button['label'].length.between?(1, 80) &&
        button['label_en'].to_s.length <= 80 && %w[primary secondary].include?(button['style']) &&
        valid_destination?(button['action'], button['value'].to_s, tenant)
    end
  end

  def self.valid_destination?(action, value, tenant)
    return false if value.length > 1000 || value.match?(/[\r\n]/)
    case action
    when 'contact' then true
    when 'page' then value.match?(/\A\d+\z/) && tenant&.pages&.exists?(id: value)
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
