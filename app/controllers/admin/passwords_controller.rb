class Admin::PasswordsController < Devise::PasswordsController
  before_action -> { response.headers["Cache-Control"] = "no-store, private"; response.headers["Referrer-Policy"] = "no-referrer" }
  before_action :private_entry!, only: %i[new create]
  before_action :reset_token_matches_site!, only: %i[edit update]

  private

  def after_sending_reset_password_instructions_path_for(_resource_name)
    new_user_session_path(access_key: session[:admin_access_key])
  end

  def assert_reset_token_passed
    head :not_found if params[:reset_password_token].blank?
  end

  def resource_params
    permitted = params.fetch(:user, {}).permit(:email, :password, :password_confirmation, :reset_password_token)
    permitted[:tenant_id] = @login_tenant.id if @login_tenant
    permitted
  end

  def reset_token_matches_site!
    token = params[:reset_password_token] || params.dig(:user, :reset_password_token)
    return unless token.is_a?(String) && token.present?
    digest = Devise.token_generator.digest(User, :reset_password_token, token)
    user = User.find_by(reset_password_token: digest)
    head :not_found if user && !PublicHost.matches_tenant?(request.host, user.tenant)
  end

  def private_entry!
    @login_tenant = Tenant.from_access_key(params[:access_key] || session[:admin_access_key])
    raise ActiveRecord::RecordNotFound unless @login_tenant && PublicHost.matches_tenant?(request.host, @login_tenant)
    session[:admin_access_key] = params[:access_key] if params[:access_key].present?
    if action_name == "create"
      params.require(:user)[:tenant_id] = @login_tenant.id
      devise_parameter_sanitizer.permit(:account_update, keys: [:tenant_id])
    end
  end
end
