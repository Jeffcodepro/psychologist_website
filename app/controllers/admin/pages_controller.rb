class Admin::PagesController < Admin::BaseController
  before_action :set_page, only: %i[edit update destroy]

  def index
    @pages = Page.ordered
  end

  def new
    @page = Page.new(
      show_in_nav: true,
      position: Page.maximum(:position).to_i + 1
    )
  end

  def create
    @page = Page.new(page_params)

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
  end

  def update
    if @page.update(page_params)
      redirect_to(
        admin_pages_path,
        notice: "Página atualizada com sucesso."
      )
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def destroy
    @page.destroy!

    redirect_to(
      admin_pages_path,
      notice: "Página removida com sucesso."
    )
  end

  private

  def set_page
    @page = Page.find(params[:id])
  end

  def page_params
    params
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
  end
end
