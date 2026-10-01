# Resolve only known tenant/platform hosts; never redirect an arbitrary Host header.
class PublicHost
  def self.platform_host
    ENV.fetch("APP_HOST", "localhost:3000").split(":").first.downcase
  end

  def self.canonical(host)
    host = host.to_s.downcase
    return host if known?(host)
    bare = host.delete_prefix("www.")
    bare if bare != host && known?(bare)
  end

  def self.tenant(host)
    canonical_host = canonical(host)
    Tenant.find_by(domain: canonical_host, active: true) if canonical_host
  end

  def self.matches_tenant?(host, candidate)
    owner = tenant(host)
    owner.nil? || owner.id == candidate.id
  end

  def self.known?(host)
    host == platform_host || Tenant.exists?(domain: host, active: true)
  end
end
