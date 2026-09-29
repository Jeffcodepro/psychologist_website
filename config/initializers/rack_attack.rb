# Redis shares counters across workers/instances. A file store is sufficient for
# the local, single-host environment and works even with Rails caching disabled.
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
Rack::Attack.throttle("contact/ip", limit: 10, period: 10.minutes) do |req|
  req.ip if req.post? && req.path.match?(%r{/(?:s/[^/]+/)?contato\z})
end
Rack::Attack.throttle("translation/ip", limit: 30, period: 10.minutes) do |req|
  req.ip if req.post? && req.path == "/admin/translation"
end
Rack::Attack.throttled_responder = lambda do |_request|
  [429, { "content-type" => "text/plain; charset=utf-8", "retry-after" => "900" }, ["Muitas tentativas. Aguarde alguns minutos e tente novamente."]]
end
Rails.application.config.middleware.use Rack::Attack
