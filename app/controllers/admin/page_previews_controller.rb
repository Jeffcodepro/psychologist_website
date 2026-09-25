class Admin::PagePreviewsController < Admin::BaseController
  before_action :set_page
  before_action :set_site_setting
  before_action :set_navigation_pages

  def show
    @preview_locale =
      %w[pt-BR en].include?(params[:locale]) ?
        params[:locale] :
        "pt-BR"
  end

  def frame
    @sections = @page
      .sections
      .draft
      .visible
      .ordered

    render layout: "admin_preview_frame"
  end

  private

  def set_page
    @page = Page.find(params[:page_id])
  end

  def set_site_setting
    @site_setting = SiteSetting.first
  end

  def set_navigation_pages
    @navigation_pages = Page
      .ordered
      .where(show_in_nav: true)
  end
end
