class AdminAccessFailure < Devise::FailureApp
  def redirect_url
    key = request.params["access_key"] || request.session[:admin_access_key]
    return "/404.html" unless Tenant.from_access_key(key)
    Rails.application.routes.url_helpers.new_user_session_path(access_key: key)
  end
end
