require "test_helper"

class Admin::SitePublicationsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Publicação", slug: "publicacao", primary: true)
    @tenant.create_site_setting!(professional_name: "Autora")
    sign_in @tenant.users.create!(admin: true, email: "publish@example.test", password: "Publish-password-123!")
    @home = @tenant.pages.create!(name: "Início", slug: "home")
    @home.sections.create!(section_type: "hero", title: "Antigo")
    @contact = @tenant.pages.create!(name: "Contato", slug: "contato")
    @form = @contact.sections.create!(section_type: "contact")
    [@home, @contact].each { |page| PagePublicationService.new(page: page).call }
    @home.sections.draft.first.update!(title: "Novo")
    @form.update!(form_position: "after_text", form_alignment: "right")
  end

  test "review and joint publication update home and contact together leaving unselected texts in draft" do
    draft = @tenant.pages.create!(name: "Ainda escrevendo", content_kind: "article")
    draft.sections.create!(section_type: "text", body: "Inacabado")
    get new_admin_site_publication_path
    assert_response :success
    assert_select 'input[type=checkbox][name="page_ids[]"]', count: 3
    post admin_site_publication_path, params: { page_ids: [@home.id, @contact.id] }
    assert_response :see_other
    assert_equal "Novo", @home.sections.published.first.title
    assert_equal "right", @contact.sections.published.first.form_alignment
    assert_not draft.reload.published?
  end

  test "one invalid draft rolls back every selected publication" do
    original = @home.sections.published.first.id
    @form.update_column(:image_shape, "invalid")
    post admin_site_publication_path, params: { page_ids: [@home.id, @contact.id] }
    assert_response :see_other
    assert_match /Nenhuma/, flash[:alert]
    assert_equal original, @home.sections.published.first.id
    assert_equal "Antigo", @home.sections.published.first.title
  end

  test "foreign or empty selections cannot publish any page" do
    foreign = Tenant.create!(name: "Outro", slug: "outro-site").pages.create!(name: "Privado")
    post admin_site_publication_path, params: { page_ids: [] }
    assert_response :see_other
    assert_match /Selecione/, flash[:alert]
    [[@home.id, foreign.id]].each do |ids|
      post admin_site_publication_path, params: { page_ids: ids }
      assert_response :not_found
      assert_equal "Antigo", @home.sections.published.first.title
    end
  end
end
