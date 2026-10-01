class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :require_site_host!
  include SafeUploads
  before_action :prevent_admin_caching
  before_action -> { @admin_site_setting = current_tenant.site_setting }
  helper_method :current_tenant

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
  layout "admin"

  private

  def current_tenant
    current_user.tenant
  end

  def authenticate_user!
    return if user_signed_in?
    key = session[:admin_access_key]
    if Tenant.from_access_key(key)
      redirect_to new_user_session_path(access_key: key)
    else
      head :not_found
    end
  end

  def require_admin!
    head :forbidden unless current_user&.admin? && current_tenant.active?
  end

  def require_site_host!
    head :not_found unless PublicHost.matches_tenant?(request.host, current_tenant)
  end

  def prevent_admin_caching
    response.headers["Cache-Control"] = "no-store, private"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end

  def safe_preview_return_path
    candidate = params[:return_to].to_s
    uri = URI.parse(candidate)
    expected = URI.parse(admin_page_preview_frame_path(@page)).path
    candidate if uri.host.nil? && uri.scheme.nil? && uri.path == expected && !candidate.start_with?("//")
  rescue URI::InvalidURIError
    nil
  end

  public

  def default_url_options
    { locale: I18n.locale }
  end
end
