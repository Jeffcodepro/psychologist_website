# Keep these rules aligned with contact_validation_controller.js.
class ContactIdentity
  COUNTRIES = JSON.parse(Rails.root.join("config/phone_countries.json").read).map(&:freeze).freeze
  COUNTRY_CODES = COUNTRIES.map { |country| country.fetch("code") }.freeze
  NAME_PART = /\A\p{L}[\p{L}\p{M}]*(?:['’\-][\p{L}\p{M}]+)*\z/
  EMAIL_LOCAL = /\A[A-Za-z0-9.!\#$%&'*+\/?^_`{|}~=\-]+\z/
  DOMAIN_LABEL = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/i

  def self.name?(value)
    parts = value.unicode_normalize(:nfc).split
    value.length <= 254 && parts.size >= 2 && parts.all? { |part| part.match?(NAME_PART) }
  end

  def self.email?(value)
    local, domain, extra = value.split("@", -1)
    return false if extra || local.blank? || domain.blank? || value.length > 254 || local.length > 64
    return false unless local.match?(EMAIL_LOCAL) && !local.start_with?(".") && !local.end_with?(".") && !local.include?("..")
    labels = domain.split(".", -1)
    labels.size >= 2 && labels.all? { |label| label.match?(DOMAIN_LABEL) } && labels.last.match?(/\A[a-z]{2,63}\z/i)
  end

  def self.phone(value, country)
    return unless COUNTRY_CODES.include?(country) && value.length <= 32 && value.match?(/\A\+?[0-9 ().\-]+\z/)
    parsed = Phonelib.parse(value, country)
    parsed.full_e164 if parsed.valid_for_country?(country) && parsed.extension.blank?
  end

  def self.message(kind)
    messages = {
      name: ["Informe pelo menos nome e sobrenome, sem números.", "Enter at least a first and last name, without numbers."],
      tel: ["Informe um telefone válido para o país selecionado, incluindo o código de área quando necessário.", "Enter a valid phone number for the selected country, including an area code when needed."],
      email: ["Informe um e-mail válido, como nome@exemplo.com.", "Enter a valid email address, such as name@example.com."]
    }
    messages.fetch(kind.to_sym)[I18n.locale == :en ? 1 : 0]
  end
end
