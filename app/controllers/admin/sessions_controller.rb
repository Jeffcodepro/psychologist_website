class Admin::SessionsController < Devise::SessionsController
  before_action :private_entry!, only: %i[new create]

  private

  def private_entry!
    @login_tenant = Tenant.from_access_key(params[:access_key])
    raise ActiveRecord::RecordNotFound unless @login_tenant
    session[:admin_access_key] = params[:access_key]
    if action_name == "create"
      params.require(:user)[:tenant_id] = @login_tenant.id.to_s
      request.request_parameters.fetch("user")["tenant_id"] = @login_tenant.id.to_s
      request.params.fetch("user")["tenant_id"] = @login_tenant.id.to_s
      devise_parameter_sanitizer.permit(:sign_in, keys: [:tenant_id])
    end
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    response.headers["Cache-Control"] = "no-store, private"
  end
end
