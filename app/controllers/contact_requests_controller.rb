class ContactRequestsController < ApplicationController
  def create
    @contact_request = ContactRequest.new(contact_request_params)
    @contact_request.source_path = params[:source_path].to_s.truncate(200)
    @contact_request.validate
    if @contact_request.website.present?
      @sent = true
    elsif @contact_request.errors.empty?
      if too_many_requests?
        @contact_request.errors.add(:base, "Aguarde alguns minutos antes de enviar uma nova mensagem.")
      else
        @sent = @contact_request.save
        session[:contact_sent_at] = Time.current.to_i if @sent
      end
    end
    render partial: "shared/contact_form", locals: { contact_request: @contact_request, sent: @sent }, status: @sent ? :ok : :unprocessable_entity
  end

  private

  def too_many_requests?
    session[:contact_sent_at].to_i > 1.minute.ago.to_i
  end

  def contact_request_params
    params.require(:contact_request).permit(:full_name, :phone, :email, :message, :website)
  end
end
