class ApplicationController < ActionController::Base
  layout :application_layout
  # ==================================================
  # LOCALE
  # ==================================================

  around_action :switch_locale

  # ==================================================
  # AFTER LOGIN
  # ==================================================

  def after_sign_in_path_for(_resource)
    admin_root_path
  end

  # ==================================================
  # AFTER LOGOUT
  # ==================================================

  def after_sign_out_path_for(_resource_or_scope)
    key = session[:admin_access_key]
    Tenant.from_access_key(key) ? new_user_session_path(access_key: key) : root_path
  end

  private

  def application_layout
    devise_controller? ? "authentication" : "application"
  end

  # ==================================================
  # LOCALE
  # ==================================================

  def switch_locale(&action)
    locale =
      requested_locale

    I18n.with_locale(
      locale,
      &action
    )
  end

  def requested_locale
    locale =
      params[:locale].presence

    admin_request = request.path.start_with?("/admin")
    return session[:admin_preview_locale].presence || I18n.default_locale if locale.blank? && admin_request
    return I18n.default_locale if locale.blank?

    available =
      I18n
        .available_locales
        .map(&:to_s)

    if available.include?(locale.to_s)
      session[:admin_preview_locale] = locale if admin_request
      locale
    else
      I18n.default_locale
    end
  end
end
