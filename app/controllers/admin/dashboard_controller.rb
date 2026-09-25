class Admin::DashboardController < Admin::BaseController
  def index
    @pages =
      Page.order(:name)

    @home_page =
      Page.find_by(slug: "home") ||
        @pages.first

    @site_setting =
      SiteSetting.first

    @draft_sections_count =
      Section.draft.count

    @published_sections_count =
      Section.published.count

    @seo_configured =
      @site_setting.present? &&
      @site_setting.seo_configured?
  end
end
