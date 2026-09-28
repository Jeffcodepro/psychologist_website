class ContactsController < ApplicationController
  def show
    @site_setting = SiteSetting.first
    @navigation_pages = Page.published.navigation
  end
end
