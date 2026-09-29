class Admin::ArticlesController < Admin::BaseController
  def index
    @articles = current_tenant.pages.editorial.order(updated_at: :desc)
  end

  def new
    @page = current_tenant.pages.new(content_kind: 'article', show_in_nav: false,
      position: current_tenant.pages.maximum(:position).to_i + 1)
  end

  def create
    @page = current_tenant.pages.new(show_in_nav: false)
    @page.assign_attributes(article_params)
    @page.position ||= current_tenant.pages.maximum(:position).to_i + 1
    if Page::EDITORIAL_KINDS.value?(@page.content_kind) && @page.valid?
      Page.transaction do
        @page.save!
        @page.sections.create!(section_type: 'hero', position: 1, title: @page.name)
        @page.sections.create!(section_type: 'text', position: 2)
        ArticleCardService.new(article: @page).save!(section_choice: params[:card_section])
      end
      redirect_to admin_page_sections_path(@page), notice: 'Texto e card de apresentação criados em rascunho. O card já está associado à página Conteúdos.'
    else
      @page.errors.add(:content_kind, 'escolha Artigo ou Reflexão') unless Page::EDITORIAL_KINDS.value?(@page.content_kind)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def article_params
    params.require(:page).permit(:name, :slug, :content_kind, :description, :description_en,
      :nav_label, :nav_label_en, :show_in_nav, :position,
      :seo_title, :seo_title_en, :seo_description, :seo_description_en)
  end
end
