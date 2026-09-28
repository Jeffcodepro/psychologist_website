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
    root_path
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

    return I18n.default_locale if locale.blank?

    available =
      I18n
        .available_locales
        .map(&:to_s)

    if available.include?(locale.to_s)
      locale
    else
      I18n.default_locale
    end
  end
end
