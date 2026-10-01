class PublicController < ApplicationController
  before_action :keep_admin_in_cms
  before_action :resolve_public_tenant
  before_action :redirect_public_alias
  before_action :remove_legacy_locale
  before_action :prevent_shared_language_caching
  around_action :published_snapshot, if: -> { request.get? || request.head? }
  helper_method :current_tenant

  def default_url_options
    { site_slug: params[:site_slug] }.compact
  end

  private

  def requested_locale
    supported_locale(params[:locale]) || supported_locale(cookies.encrypted[:site_locale]) || I18n.default_locale
  end

  def supported_locale(value)
    value if value.is_a?(String) && I18n.available_locales.map(&:to_s).include?(value)
  end

  def remember_locale(locale)
    cookies.encrypted[:site_locale] = {
      value: locale, expires: 1.year.from_now,
      httponly: true, same_site: :lax, secure: Rails.env.production?
    }
  end

  def remove_legacy_locale
    return unless (request.get? || request.head?) && request.query_parameters.key?("locale")

    locale = supported_locale(params[:locale])
    remember_locale(locale) if locale
    query = request.query_parameters.except("locale").to_query
    destination = request.path + (query.present? ? "?#{query}" : "")
    response.headers["Cache-Control"] = "no-store, private"
    redirect_to destination, status: :see_other
  end

  def prevent_shared_language_caching
    # The same URL can contain different languages for different visitors.
    response.headers["Cache-Control"] = "private, max-age=0, must-revalidate"
  end

  def keep_admin_in_cms
    if user_signed_in?
      response.headers["Cache-Control"] = "no-store, private"
      redirect_to admin_root_path
    end
  end

  def resolve_public_tenant
    domain_tenant = Tenant.find_by(domain: public_host, active: true)
    @current_tenant = if params[:site_slug].present?
      raise ActiveRecord::RecordNotFound if domain_tenant && domain_tenant.slug != params[:site_slug]
      raise ActiveRecord::RecordNotFound unless domain_tenant || platform_host?
      domain_tenant || Tenant.find_by!(slug: params[:site_slug], active: true)
    else
      domain_tenant || (Tenant.find_by(primary: true, active: true) if platform_host?)
    end
    raise ActiveRecord::RecordNotFound unless @current_tenant
    @site_setting = @current_tenant.site_setting
    @navigation_pages = @current_tenant.pages.published.navigation
  end

  def current_tenant
    @current_tenant
  end

  # A visitor sees one consistent publication, including cards and attachments,
  # even when an administrator replaces the published sections during rendering.
  def published_snapshot
    if ApplicationRecord.connection.transaction_open?
      yield
    else
      ApplicationRecord.transaction(isolation: :repeatable_read) { yield }
    end
  end

  def public_host
    @public_host ||= PublicHost.canonical(request.host) || request.host.downcase
  end

  def redirect_public_alias
    return if public_host == request.host.downcase
    redirect_to "#{request.protocol}#{public_host}#{request.fullpath}", status: :moved_permanently, allow_other_host: true
  end

  def platform_host?
    hosts = [ENV.fetch("APP_HOST", "localhost:3000").split(":").first]
    hosts += %w[localhost 127.0.0.1 www.example.com] unless Rails.env.production?
    hosts.include?(public_host)
  end
end
