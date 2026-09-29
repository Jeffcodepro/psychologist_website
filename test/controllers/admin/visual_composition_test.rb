require "test_helper"

class Admin::VisualCompositionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Teste", slug: "teste", primary: true)
    sign_in @tenant.users.create!(admin: true, email: "composition-admin@example.test", password: "Local-test-password-123!")
    @page = @tenant.pages.create!(name: "Composição", slug: "composition-test")
    @section = @page.sections.create!(section_type: "hero", title: "Título", body: "Parágrafo")
  end

  test "dragging paragraph on mobile preserves desktop composition" do
    patch admin_page_section_path(@page, @section), params: { section: { responsive_settings: { mobile: { text_order: "body_first", body_alignment: "right" } } } }, as: :json
    assert_response :success
    assert_equal "title_first", @section.reload.text_order
    assert_equal "body_first", @section.visual_value("text_order", "mobile")
    assert_equal "right", @section.visual_value("body_alignment", "mobile")
    assert_includes response.parsed_body.fetch("style_variables"), "--mobile-body-order: 1"
    assert_includes response.parsed_body.fetch("style_variables"), "--desktop-body-order: 2"
    get admin_page_preview_frame_path(@page)
    assert_response :success
    assert_select '[data-controller="visual-drag"]'
    assert_select '.preview-movable--title .element-grip'
    assert_select '.preview-movable--body .element-grip'
    assert_select '.preview-field-handle-layer, .preview-composition-bar', count: 0
  end

  test "new heroes do not opt into a shared photo" do
    assert_not @section.use_profile_image?
    get admin_page_preview_frame_path(@page)
    assert_response :success
    assert_select '.flexible-section__media', count: 0
  end

  test "pages and blocks expose working deletion controls" do
    PagePublicationService.new(page: @page).call
    get admin_pages_path
    assert_response :success
    assert_select "form[action='#{admin_page_path(@page, locale: 'pt-BR')}'] button", text: "Excluir página"
    get admin_page_sections_path(@page)
    assert_response :success
    assert_select "form[action='#{admin_page_section_path(@page, @section, locale: 'pt-BR')}'] button", text: "Excluir bloco"
    delete admin_page_section_path(@page, @section)
    assert_redirected_to admin_page_sections_path(@page, locale: "pt-BR")
    assert_equal 0, @page.sections.draft.count
    assert_equal 1, @page.sections.published.count
    assert_difference "Page.count", -1 do
      delete admin_page_path(@page)
    end
    assert_equal 0, Section.where(page_id: @page.id).count
  end
end
