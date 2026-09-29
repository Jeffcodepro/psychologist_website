class PublicController < ApplicationController
  before_action :keep_admin_in_cms
  before_action :resolve_public_tenant
  helper_method :current_tenant

  def default_url_options
    { site_slug: params[:site_slug], locale: I18n.locale }.compact
  end

  private

  def keep_admin_in_cms
    redirect_to admin_root_path if user_signed_in?
  end

  def resolve_public_tenant
    @current_tenant = if params[:site_slug].present?
      Tenant.find_by!(slug: params[:site_slug], active: true)
    else
      Tenant.find_by(domain: request.host.downcase, active: true) ||
        (Tenant.find_by(primary: true, active: true) if platform_host?)
    end
    raise ActiveRecord::RecordNotFound unless @current_tenant
    @site_setting = @current_tenant.site_setting
    @navigation_pages = @current_tenant.pages.published.navigation
  end

  def current_tenant
    @current_tenant
  end

  def platform_host?
    hosts = [ENV.fetch("APP_HOST", "localhost:3000").split(":").first]
    hosts += %w[localhost 127.0.0.1 www.example.com] unless Rails.env.production?
    hosts.include?(request.host)
  end
end
