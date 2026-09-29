class Admin::ContactRequestsController < Admin::BaseController
  def index
    @page_number = [params[:page].to_i, 1].max
    @total_pages = [(current_tenant.contact_requests.count / 25.0).ceil, 1].max
    @page_number = [@page_number, @total_pages].min
    @contact_requests = current_tenant.contact_requests.recent.limit(25).offset((@page_number - 1) * 25)
  end

  def show
    @contact_request = current_tenant.contact_requests.find(params[:id])
    @contact_request.update!(read_at: Time.current) unless @contact_request.read_at
  end

  def destroy
    current_tenant.contact_requests.find(params[:id]).destroy!
    redirect_to admin_contact_requests_path, notice: "Mensagem excluída.", status: :see_other
  end

  def deliver
    contact = current_tenant.contact_requests.find(params[:id])
    delivered = EmailDelivery.call(contact)
    options = delivered ? { notice: "E-mail enviado." } : { alert: contact.email_delivery_error }
    redirect_to admin_contact_request_path(contact), **options, status: :see_other
  end
end
