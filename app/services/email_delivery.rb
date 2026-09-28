class EmailDelivery
  REQUIRED_KEYS = %w[SMTP_ADDRESS SMTP_USERNAME SMTP_PASSWORD MAILER_FROM CONTACT_RECIPIENT].freeze

  def self.configured?
    REQUIRED_KEYS.all? { |key| ENV[key].present? }
  end

  def self.call(contact)
    return true if contact.email_delivered_at?
    unless configured?
      contact.update_columns(email_delivery_error: "Configure o serviço de e-mail para enviar esta mensagem.")
      return false
    end

    ContactMailer.with(contact: contact).notification.deliver_now
    contact.update_columns(email_delivered_at: Time.current, email_delivery_error: nil)
    true
  rescue StandardError => error
    Rails.logger.error("Contact email delivery failed: #{error.class.name}")
    contact.update_columns(email_delivery_error: "O e-mail não foi entregue. Verifique a configuração e tente reenviar.")
    false
  end
end
