Rails.application.config.after_initialize do
  Rails.logger.formatter = PrivateAccessLogFormatter.new(Rails.logger.formatter || ActiveSupport::Logger::SimpleFormatter.new)
end
