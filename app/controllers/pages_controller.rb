class PagesController < ApplicationController
  before_action :set_site_setting
  before_action :set_navigation_pages

  def home
    @page = Page.find_by!(
      slug: "home",
      published: true
    )

    load_sections
  end

  def show
    @page = Page.find_by!(
      slug: params[:slug],
      published: true
    )

    load_sections
    render :home
  end

  private

  def set_site_setting
    @site_setting = SiteSetting.first
  end

  def set_navigation_pages
    @navigation_pages = Page
      .published
      .navigation
  end

  def load_sections
    @sections = @page
      .sections
      .published
      .visible
      .ordered
  end
end
