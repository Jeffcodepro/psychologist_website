Rails.application.config.action_dispatch.default_headers.merge!(
  "X-Content-Type-Options" => "nosniff",
  "Referrer-Policy" => "strict-origin-when-cross-origin",
  "Permissions-Policy" => "camera=(), microphone=(), geolocation=()"
)
Rails.application.config.active_storage.service_urls_expire_in = 5.minutes
