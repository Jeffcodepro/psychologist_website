class PagesController < PublicController

  def home
    @page = current_tenant.pages.find_by(slug: "home", published: true) || current_tenant.pages.site_pages.published.ordered.first
    raise ActiveRecord::RecordNotFound unless @page

    load_sections
  end

  def show
    @page = current_tenant.pages.find_by!(
      slug: params[:slug],
      published: true
    )

    load_sections
    render :home
  end

  private

  def load_sections
    @sections = @page
      .sections
      .published
      .visible
      .ordered
  end
end
