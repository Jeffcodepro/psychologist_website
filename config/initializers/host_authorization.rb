if Rails.env.production?
  Rails.application.config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  Rails.application.config.hosts = [
    ENV.fetch("APP_HOST", "localhost").split(":").first,
    ->(host) { PublicHost.canonical(host.split(":").first).present? }
  ]
end
