class ContactsController < PublicController
  def show
    @page = current_tenant.pages.published.find_by!(slug: "contato")
    @sections = @page.sections.published.visible.ordered
    render "pages/home"
  end
end
