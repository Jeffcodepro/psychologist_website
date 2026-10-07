class Admin::ArticleCardsController < Admin::BaseController
  before_action :set_article

  def edit
    @card = @placement.build
  end

  def update
    @card = @placement.save!(attributes: card_params, section_choice: params[:card_section])
    redirect_to edit_admin_article_card_path(@article), notice: 'Card salvo em Conteúdos. Publique a página Conteúdos quando estiver pronto.'
  rescue ActiveRecord::RecordInvalid => error
    @card = error.record
    render :edit, status: :unprocessable_entity
  end

  private

  def set_article
    @page = @article = current_tenant.pages.editorial.find(params[:article_id])
    @placement = ArticleCardService.new(article: @article)
    @section_options = @placement.section_options
    @section_choice = params[:card_section].presence || @placement.default_section_choice
  end

  def card_params
    params.require(:article_card).permit(:title, :title_en, :body, :body_en, :image, :remove_image, :video, :remove_video,
      :visible, :position, :image_position_x, :image_position_y, :image_zoom, :image_shape,
      video_settings: VideoMedia::PARAMS, card_settings: CardPresentation::PARAMS, media_adjustments: MediaAdjustable::PARAMS)
  end
end
