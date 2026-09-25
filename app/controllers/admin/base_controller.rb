class Admin::BaseController < ApplicationController
  before_action :authenticate_user!

  layout "admin"

  private

  def set_admin_locale
    I18n.locale =
      params[:locale].presence ||
      I18n.default_locale
  end
end
