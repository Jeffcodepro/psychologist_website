class ContactRequestsController < PublicController
  def create
    @form_section = current_tenant.sections.published.visible.where(section_type: "contact").joins(:page).where(pages: { published: true }).find(params[:form_section_id])
    fields = @form_section.effective_form_fields
    payload = params.require(:contact_request)
    return head :bad_request unless payload.is_a?(ActionController::Parameters)

    submitted = payload.permit(:website,
      answers: fields.map { |field| field["key"] },
      phone_countries: fields.select { |field| field["type"] == "tel" }.map { |field| field["key"] }).to_h
    return head :bad_request unless submitted.fetch(:answers, {}).is_a?(Hash) && submitted.fetch(:phone_countries, {}).is_a?(Hash)

    @contact_request = current_tenant.contact_requests.new(website: submitted[:website])
    @contact_request.assign_form(@form_section, submitted.fetch(:answers, {}), countries: submitted[:phone_countries] || {})
    @contact_request.source_path = params[:source_path].to_s.truncate(200)
    @contact_request.request_fingerprint = ContactSubmissionGuard.fingerprint(request.remote_ip)
    @contact_request.validate
    retry_after = 0

    if @contact_request.website.present?
      @sent = true
    elsif @contact_request.errors.empty?
      result = ContactSubmissionGuard.new(contact_request: @contact_request, session: session).save
      @sent = result.accepted?
      retry_after = result.retry_after
      EmailDelivery.call(@contact_request) if @sent
    end

    response.headers["Cache-Control"] = "no-store, private"
    response.headers["Retry-After"] = retry_after.to_s if retry_after.positive?
    status = @sent ? :ok : (retry_after.positive? ? :too_many_requests : :unprocessable_entity)
    render partial: "shared/contact_form", formats: [:html], locals: {
      contact_request: @contact_request, sent: @sent, form_section: @form_section, retry_after: retry_after
    }, status: status
  end
end
