if Rails.env.production?
  Rails.application.config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  Rails.application.config.hosts = [
    ENV.fetch("APP_HOST", "localhost").split(":").first,
    ->(host) { Tenant.exists?(domain: host.split(":").first.downcase, active: true) }
  ]
end
