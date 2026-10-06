class ContactRequest < ApplicationRecord
  belongs_to :tenant
  attr_accessor :website, :phone_countries
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :full_name, :phone, :message, with: ->(value) { value.strip }
  before_validation :normalize_contact_answers, if: :contact_data_changed?
  validate :validate_answers, if: :contact_data_changed?
  scope :recent, -> { order(created_at: :desc) }

  def display_name
    full_name.presence || "Contato ##{id}"
  end

  def response_fields
    if form_snapshot.present?
      form_snapshot.map { |field| [field["label"], answers[field["key"]]] }
    else
      [["Nome", full_name], ["Telefone", phone], ["E-mail", email], ["Mensagem", message]]
    end
  end

  def assign_form(section, submitted, countries: {})
    self.phone_countries = countries.to_h.stringify_keys
    self.form_snapshot = section.effective_form_fields.deep_dup
    self.answers = form_snapshot.to_h { |field| [field["key"], submitted[field["key"]].to_s.strip] }
    self.full_name = answers.fetch("full_name", value_for_type("name"))
    self.phone = value_for_type("tel")
    self.email = value_for_type("email").downcase
    self.message = value_for_type("textarea")
  end

  def phone_country(key, value = nil)
    return phone_countries[key].to_s.upcase if phone_countries.is_a?(Hash) && phone_countries.key?(key)
    value = answers[key].presence || value || phone
    value.to_s.start_with?("+") ? (Phonelib.parse(value).country || "BR") : "BR"
  end

  private

  def contact_data_changed?
    new_record? || (changes.keys & %w[answers form_snapshot full_name phone email message]).any?
  end

  def normalize_contact_answers
    return unless answers.is_a?(Hash)
    if form_snapshot.present? && ContactFormSchema.valid?(form_snapshot)
      self.answers = answers.deep_dup
      form_snapshot.each do |field|
        key = field["key"]
        value = answers[key].to_s.strip
        value = value.unicode_normalize(:nfc).split.join(" ") if field["type"] == "name" || key == "full_name"
        value = value.downcase if field["type"] == "email"
        value = ContactIdentity.phone(value, phone_country(key, value)) || value if field["type"] == "tel"
        answers[key] = value
      end
      self.full_name = answers.fetch("full_name", value_for_type("name"))
      self.phone = value_for_type("tel")
      self.email = value_for_type("email")
      self.message = value_for_type("textarea")
    else
      self.full_name = full_name.to_s.unicode_normalize(:nfc).split.join(" ")
      self.phone = ContactIdentity.phone(phone.to_s, phone_country("phone")) || phone
    end
  end

  def value_for_type(type)
    field = form_snapshot.find { |item| item["type"] == type }
    field ? answers[field["key"]].to_s : ""
  end

  def validate_answers
    fields = form_snapshot.presence || ContactFormSchema::DEFAULT_FIELDS
    unless ContactFormSchema.valid?(fields) && answers.is_a?(Hash)
      errors.add(:base, "Formulário inválido.")
      return
    end
    fields.each do |field|
      value = form_snapshot.present? ? answers[field["key"]].to_s : public_send(field["key"]).to_s
      label = ContactFormSchema.label(field)
      if field["required"] && (value.blank? || (field["type"] == "checkbox" && value != "1"))
        errors.add(:base, "#{label}: #{I18n.locale == :en ? 'required field' : 'preenchimento obrigatório'}")
        next
      end
      next if value.blank?
      valid = value.length <= (field["type"] == "textarea" ? 5000 : 254)
      valid &&= case field["type"]
      when "name" then ContactIdentity.name?(value)
      when "email" then ContactIdentity.email?(value)
      when "tel" then ContactIdentity.phone(value, phone_country(field["key"], value)).present?
      when "select" then field["options"].include?(value)
      when "checkbox" then %w[0 1].include?(value)
      when "date" then value.match?(/\A\d{4}-\d{2}-\d{2}\z/) && (Date.iso8601(value) rescue false)
      else true
      end
      name_field = field["type"] == "name" || field["key"] == "full_name"
      valid &&= ContactIdentity.name?(value) if name_field
      unless valid
        kind = name_field ? "name" : field["type"]
        reason = %w[name email tel].include?(kind) ? ContactIdentity.message(kind) : (I18n.locale == :en ? "invalid value" : "valor inválido")
        errors.add(:base, "#{label}: #{reason}")
      end
    end
  end
end
