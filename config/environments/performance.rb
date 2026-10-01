# Local benchmarks only: dedicated synthetic data, no external services.
raise "Performance uses its own local database; unset DATABASE_URL." if ENV["DATABASE_URL"].present?
require_relative "production"

Rails.application.configure do
  config.require_master_key = false
  config.secret_key_base = SecureRandom.hex(64)
  config.force_ssl = false
  config.assume_ssl = false
  config.hosts = %w[127.0.0.1 localhost rosemary.performance.test thiago.performance.test]
  config.active_storage.service = :performance
  config.active_job.queue_adapter = :test
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = false
  # Warmed once before measurement; static assets and CDN are not load-tested.
  config.assets.compile = true
  config.log_level = :warn
  config.logger = ActiveSupport::Logger.new(Rails.root.join("log/performance.log"))
end
