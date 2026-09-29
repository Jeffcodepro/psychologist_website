class Admin::PasswordsController < Devise::PasswordsController
  before_action -> { response.headers["Cache-Control"] = "no-store, private"; response.headers["Referrer-Policy"] = "no-referrer" }
  before_action :private_entry!, only: %i[new create]

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

  def private_entry!
    @login_tenant = Tenant.from_access_key(params[:access_key] || session[:admin_access_key])
    raise ActiveRecord::RecordNotFound unless @login_tenant
    session[:admin_access_key] = params[:access_key] if params[:access_key].present?
    if action_name == "create"
      params.require(:user)[:tenant_id] = @login_tenant.id
      devise_parameter_sanitizer.permit(:account_update, keys: [:tenant_id])
    end
  end
end
