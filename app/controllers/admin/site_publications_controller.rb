class Admin::SitePublicationsController < Admin::BaseController
  def new
    @pages = current_tenant.pages.ordered
  end

  def create
    if Array(params[:page_ids]).reject(&:blank?).empty?
      redirect_to new_admin_site_publication_path, status: :see_other, alert: "Selecione ao menos uma página para publicar."
      return
    end
    count = SitePublicationService.new(tenant: current_tenant, page_ids: params[:page_ids]).call
    redirect_to new_admin_site_publication_path, status: :see_other,
      notice: "#{count} páginas publicadas com sucesso."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => error
    Rails.logger.error("Site publication failed tenant=#{current_tenant.id} error=#{error.class} request=#{request.request_id}")
    redirect_to new_admin_site_publication_path, status: :see_other,
      alert: "A publicação não foi concluída. Nenhuma das páginas selecionadas foi alterada. Revise seus rascunhos."
  end
end
