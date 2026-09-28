class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :prevent_admin_caching
  before_action -> { @admin_site_setting = SiteSetting.first }

  layout "admin"

  private

  def require_admin!
    head :forbidden unless current_user&.admin?
  end

  def prevent_admin_caching
    response.headers["Cache-Control"] = "no-store, private"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end

  def safe_preview_return_path
    candidate = params[:return_to].to_s
    uri = URI.parse(candidate)
    expected = admin_page_preview_frame_path(@page)
    candidate if uri.host.nil? && uri.scheme.nil? && uri.path == expected && !candidate.start_with?("//")
  rescue URI::InvalidURIError
    nil
  end

  def set_admin_locale
    I18n.locale =
      params[:locale].presence ||
      I18n.default_locale
  end
end
