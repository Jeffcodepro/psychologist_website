class Admin::PagePublicationsController < Admin::BaseController
  before_action :set_page

  def create
    PagePublicationService.new(
      page: @page
    ).call

    redirect_to admin_page_preview_path(@page),
                notice: "Página publicada com sucesso."
  rescue StandardError => error
    Rails.logger.error("Publication failed page=#{@page.id} error=#{error.class} request=#{request.request_id}")
    redirect_to admin_page_preview_path(@page),
                alert: "Não foi possível concluir a publicação. Tente novamente."
  end

  private

  def set_page
    @page = current_tenant.pages.find(params[:page_id])
  end
end
