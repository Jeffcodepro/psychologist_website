class ContactsController < PublicController
  def show
    @page = current_tenant.pages.published.find_by!(slug: "contato")
    @sections = PublicContentLoader.sections(@page)
    render "pages/home"
  end
end
