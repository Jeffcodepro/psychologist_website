class Admin::DashboardController < Admin::BaseController
  def index
    @pages =
      current_tenant.pages.order(:name)

    @home_page =
      current_tenant.pages.find_by(slug: "home") ||
        @pages.first

    @site_setting =
      current_tenant.site_setting

    @draft_sections_count =
      current_tenant.sections.draft.count

    @published_sections_count =
      current_tenant.sections.published.count

    @seo_configured =
      @site_setting.present? &&
      @site_setting.seo_configured?
  end
end
