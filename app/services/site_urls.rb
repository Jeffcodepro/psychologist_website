class SiteUrls
  include Rails.application.routes.url_helpers

  def initialize(tenant, request: nil)
    host = tenant.domain.presence || ENV["APP_HOST"].presence || request&.host_with_port || "localhost:3000"
    @options = {
      host: host,
      protocol: Rails.env.production? ? "https" : (request&.protocol || "http"),
      site_slug: tenant.domain.present? || tenant.primary? ? nil : tenant.slug
    }
  end

  def home
    root_url(**@options)
  end

  def page(page)
    page.home? ? home : public_page_url(slug: page.slug, **@options)
  end

  def sitemap
    sitemap_url(**@options)
  end
end
