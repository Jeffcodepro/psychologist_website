class ContactRequest < ApplicationRecord
  belongs_to :tenant
  attr_accessor :website
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :full_name, :phone, :message, with: ->(value) { value.strip }
  validate :validate_answers
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

  def assign_form(section, submitted)
    self.form_snapshot = section.effective_form_fields.deep_dup
    self.answers = form_snapshot.to_h { |field| [field["key"], submitted[field["key"]].to_s.strip] }
    self.full_name = answers.fetch("full_name", "")
    self.phone = value_for_type("tel")
    self.email = value_for_type("email").downcase
    self.message = value_for_type("textarea")
  end

  private

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
      when "email" then value.match?(URI::MailTo::EMAIL_REGEXP) && !value.match?(/[\r\n]/)
      when "tel" then value.gsub(/\D/, "").length.between?(10, 15)
      when "select" then field["options"].include?(value)
      when "checkbox" then %w[0 1].include?(value)
      when "date" then value.match?(/\A\d{4}-\d{2}-\d{2}\z/) && (Date.iso8601(value) rescue false)
      else true
      end
      errors.add(:base, "#{label}: #{I18n.locale == :en ? 'invalid value' : 'valor inválido'}") unless valid
    end
  end
end
