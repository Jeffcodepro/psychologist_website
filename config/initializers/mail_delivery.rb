Rails.application.configure do
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "localhost:3000"),
    protocol: Rails.env.production? ? "https" : "http"
  }
  unless Rails.env.test?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS", "smtp.gmail.com"),
      port: ENV.fetch("SMTP_PORT", "587").to_i,
      domain: ENV.fetch("SMTP_DOMAIN", "localhost"),
      user_name: ENV["SMTP_USERNAME"], password: ENV["SMTP_PASSWORD"],
      authentication: :plain, enable_starttls: true,
      open_timeout: 5, read_timeout: 10
    }
  end
end
