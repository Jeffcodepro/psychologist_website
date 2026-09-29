class Admin::PagePreviewsController < Admin::BaseController
  before_action :set_page
  before_action :set_site_setting
  before_action :set_navigation_pages

  def show
    @preview_locale = I18n.locale.to_s
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
    @page = current_tenant.pages.find(params[:page_id])
  end

  def set_site_setting
    @site_setting = current_tenant.site_setting
  end

  def set_navigation_pages
    @navigation_pages = current_tenant.pages
      .ordered
      .where(show_in_nav: true)
  end
end
