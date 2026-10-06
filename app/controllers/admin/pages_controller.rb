class Admin::PagesController < Admin::BaseController
  before_action :set_page, only: %i[edit update destroy]

  def index
    @pages = current_tenant.pages.site_pages.ordered
  end

  def new
    @page = current_tenant.pages.new(
      show_in_nav: true,
      position: current_tenant.pages.maximum(:position).to_i + 1
    )
  end

  def create
    @page = current_tenant.pages.new(page_params)

    if @page.save
      redirect_to(
        admin_pages_path,
        notice: "Página criada com sucesso."
      )
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
    redirect_to edit_admin_article_path(@page) if @page.editorial?
  end

  def update
    if @page.update(page_params)
      redirect_to(
        @page.editorial? ? admin_articles_path : admin_pages_path,
        notice: "Página atualizada com sucesso."
      )
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def destroy
    editorial = @page.editorial?
    @page.destroy!

    redirect_to(
      editorial ? admin_articles_path : admin_pages_path,
      notice: "Página removida com sucesso."
    )
  end

  private

  def set_page
    @page = current_tenant.pages.find(params[:id])
  end

  def page_params
    permitted = params
      .require(:page)
      .permit(
        :name,
        :slug,
        :description,
        :description_en,
        :nav_label,
        :nav_label_en,
        :show_in_nav,
        :position,
        :seo_title,
        :seo_title_en,
        :seo_description,
        :seo_description_en
      )
    if @page&.editorial? && Page::EDITORIAL_KINDS.value?(params.dig(:page, :content_kind))
      permitted[:content_kind] = params[:page][:content_kind]
    end
    permitted
  end
end
