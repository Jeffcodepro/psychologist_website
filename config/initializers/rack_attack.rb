# Redis shares counters across workers/instances. A file store is sufficient for
# the local, single-host environment and works even with Rails caching disabled.
# Accepted contact submissions also have atomic, database-backed limits.
Rack::Attack.cache.store = if ENV["RATE_LIMIT_REDIS_URL"].present?
  ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch("RATE_LIMIT_REDIS_URL"), namespace: "cms-rate-limits")
else
  ActiveSupport::Cache::FileStore.new(Rails.root.join("tmp/rate-limits"))
end

Rack::Attack.blocklist("private-files-and-unused-upload-endpoints") do |req|
  req.path.match?(%r{(?:\A|/)(?:\.env(?:\.|/|\z)|\.git(?:/|\z)|master\.key|credentials.*\.enc)}) ||
    req.path.start_with?("/rails/active_storage/direct_uploads") ||
    (req.put? && req.path.start_with?("/rails/active_storage/disk/"))
end
Rack::Attack.throttle("authentication/ip", limit: 20, period: 15.minutes) do |req|
  req.ip if req.post? && req.path.start_with?("/admin/access/", "/admin/password")
end
contact_ip = lambda do |req|
  if req.post? && req.path.match?(%r{\A(?:/s/[^/]+)?/contato(?:\.[^/]+)?/?\z})
    # Use the same IP resolution as the controller, after Rails proxy handling.
    req.env["action_dispatch.remote_ip"]&.to_s || req.ip
  end
end
Rack::Attack.throttle("contact/burst", limit: 5, period: 10.seconds, &contact_ip)
Rack::Attack.throttle("contact/ip", limit: 10, period: 10.minutes, &contact_ip)
Rack::Attack.throttle("translation/ip", limit: 30, period: 10.minutes) do |req|
  req.ip if req.post? && req.path == "/admin/translation"
end
Rack::Attack.throttled_responder = lambda do |request|
  match = request.env.fetch("rack.attack.match_data")
  retry_after = match.fetch(:period) - (match.fetch(:epoch_time) % match.fetch(:period))
  message = "Muitas tentativas. Aguarde #{(retry_after / 60.0).ceil} minuto(s) e tente novamente."
  frame = request.get_header("HTTP_TURBO_FRAME").to_s
  content_type = "text/plain; charset=utf-8"
  if frame.match?(/\Acontact_form_[0-9]+\z/)
    content_type = "text/html; charset=utf-8"
    message = %(<turbo-frame id="#{frame}"><div class="appointment-form__errors" role="alert">#{message}</div></turbo-frame>)
  end
  [429, {
    "content-type" => content_type, "retry-after" => retry_after.to_s,
    "cache-control" => "no-store, private"
  }, [message]]
end
Rails.application.config.middleware.use Rack::Attack
