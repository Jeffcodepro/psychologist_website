class ContactRequestsController < PublicController
  def create
    @form_section = current_tenant.sections.published.visible.where(section_type: "contact").joins(:page).where(pages: { published: true }).find(params[:form_section_id])
    @contact_request = current_tenant.contact_requests.new(website: params.dig(:contact_request, :website))
    submitted = params.require(:contact_request).permit(:website, answers: @form_section.effective_form_fields.map { |f| f["key"] }).fetch(:answers, {})
    @contact_request.assign_form(@form_section, submitted)
    @contact_request.source_path = params[:source_path].to_s.truncate(200)
    @contact_request.request_fingerprint = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, request.remote_ip.to_s)
    @contact_request.validate
    if @contact_request.website.present?
      @sent = true
    elsif @contact_request.errors.empty?
      if too_many_requests?
        @contact_request.errors.add(:base, "Aguarde alguns minutos antes de enviar uma nova mensagem.")
      else
        @sent = @contact_request.save
        session[:contact_sent_at] = Time.current.to_i if @sent
        EmailDelivery.call(@contact_request) if @sent
      end
    end
    render partial: "shared/contact_form", locals: { contact_request: @contact_request, sent: @sent, form_section: @form_section }, status: @sent ? :ok : :unprocessable_entity
  end

  private

  def too_many_requests?
    session[:contact_sent_at].to_i > 1.minute.ago.to_i ||
      current_tenant.contact_requests.where(request_fingerprint: @contact_request.request_fingerprint)
        .where(created_at: 1.hour.ago..).count >= 5
  end

end
