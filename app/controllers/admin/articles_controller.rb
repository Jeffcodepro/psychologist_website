class Admin::ArticlesController < Admin::BaseController
  before_action :set_article, only: %i[edit update]

  def index
    @articles = current_tenant.pages.editorial.order(updated_at: :desc)
  end

  def new
    @page = current_tenant.pages.new(content_kind: "article", show_in_nav: false,
      position: current_tenant.pages.maximum(:position).to_i + 1)
    @editor = ArticleEditor.new(page: @page)
  end

  def create
    @page = current_tenant.pages.new(content_kind: "article", show_in_nav: false,
      position: current_tenant.pages.maximum(:position).to_i + 1)
    @editor = ArticleEditor.new(page: @page)
    if save_article
      redirect_to edit_admin_article_path(@page), status: :see_other,
        notice: "Texto salvo em rascunho e card criado em Conteúdos. Revise a prévia antes de publicar."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if save_article
      redirect_to edit_admin_article_path(@page), status: :see_other,
        notice: "Rascunho salvo. Revise e publique para atualizar o texto no site."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_article
    @page = current_tenant.pages.editorial.find(params[:id])
    @editor = ArticleEditor.new(page: @page)
  end

  def save_article
    @editor.save(page_attributes: article_params,
      content_attributes: params.fetch(:article_content, ActionController::Parameters.new).permit(:title_en, :body, :body_en),
      card_section: params[:card_section])
  end

  def article_params
    params.require(:page).permit(:name, :slug, :content_kind, :description, :description_en,
      :seo_title, :seo_title_en, :seo_description, :seo_description_en)
  end
end
