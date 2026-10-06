class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :require_site_host!
  include SafeUploads
  before_action :prevent_admin_caching
  before_action :remove_legacy_locale
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

  def remove_legacy_locale
    return unless (request.get? || request.head?) && request.query_parameters.key?("locale")
    query = request.query_parameters.except("locale").to_query
    redirect_to request.path + (query.present? ? "?#{query}" : ""), status: :see_other
  end

  def safe_preview_return_path
    candidate = params[:return_to].to_s
    uri = URI.parse(candidate)
    expected = URI.parse(admin_page_preview_frame_path(@page)).path
    return unless uri.host.nil? && uri.scheme.nil? && uri.path == expected && !candidate.start_with?("//")
    query = URI.decode_www_form(uri.query.to_s).reject { |key, _| key == "locale" || key.start_with?("locale[") }
    uri.path + (query.any? ? "?#{URI.encode_www_form(query)}" : "")
  rescue URI::InvalidURIError
    nil
  end

  public

  def default_url_options
    {}
  end
end
