class DiscoveryController < PublicController
  skip_before_action :keep_admin_in_cms

  def sitemap
    @pages = current_tenant.pages.published.ordered.limit(50_000)
    @urls = SiteUrls.new(current_tenant, request: request)
    response.headers["Cache-Control"] = "no-cache"
    render formats: :xml
  end

  def robots
    urls = SiteUrls.new(current_tenant, request: request)
    response.headers["Cache-Control"] = "no-cache"
    render plain: "User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /rails/\nDisallow: /users/\n\nSitemap: #{urls.sitemap}\n"
  end
end
