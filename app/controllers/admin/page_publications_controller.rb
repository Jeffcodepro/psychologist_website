class Admin::PagePublicationsController < Admin::BaseController
  before_action :set_page

  def create
    PagePublicationService.new(
      page: @page
    ).call

    redirect_to admin_page_preview_path(@page),
                notice: "Página publicada com sucesso."
  rescue StandardError => e
    redirect_to admin_page_preview_path(@page),
                alert: "Não foi possível publicar: #{e.message}"
  end

  private

  def set_page
    @page = Page.find(params[:page_id])
  end
end
