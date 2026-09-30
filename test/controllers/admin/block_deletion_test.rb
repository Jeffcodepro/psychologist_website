require "test_helper"

class Admin::BlockDeletionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Exclusão", slug: "exclusao", primary: true)
    sign_in @tenant.users.create!(admin: true, email: "delete@example.test", password: "Deletion-test-password-123!")
    @page = @tenant.pages.create!(name: "Blocos", slug: "blocos")
    @section = @page.sections.create!(section_type: "text", title: "Excluir", position: 1)
    @remaining = @page.sections.create!(section_type: "text", title: "Manter", position: 2)
    PagePublicationService.new(page: @page).call
  end

  test "preview delete is a form and returns to the same preview with a GET" do
    destination = admin_page_preview_frame_path(@page, locale: :en)
    get destination
    assert_select "form[action='#{admin_page_section_path(@page, @section, locale: :en)}'][method='post']" do
      assert_select "input[name='_method'][value='delete']"
      assert_select "input[name='return_to'][value='#{destination}']"
      assert_select "button", text: "Excluir bloco"
    end
    delete admin_page_section_path(@page, @section, locale: :en), params: { return_to: destination }
    assert_response :see_other
    assert_redirected_to destination
    follow_redirect!
    assert_response :success
    assert_equal "GET", request.request_method
    assert_select ".preview-live-editor"
    assert_select "[data-preview-section-id='#{@section.id}']", count: 0
    assert_equal 1, @remaining.reload.position
    assert_equal 2, @page.sections.published.count
  end

  test "a crafted return URL cannot leave the current tenant preview" do
    delete admin_page_section_path(@page, @section), params: { return_to: "https://external.example/admin/pages/#{@page.id}/preview/frame" }
    assert_response :see_other
    assert_redirected_to admin_page_sections_path(@page, locale: "pt-BR")
  end

  test "published and foreign blocks cannot be deleted through a crafted request" do
    foreign = Tenant.create!(name: "Outro", slug: "outro")
    foreign_page = foreign.pages.create!(name: "Outro", slug: "outro")
    foreign_section = foreign_page.sections.create!(section_type: "text", title: "Protegido")
    published = @page.sections.published.first
    [[@page, published], [foreign_page, foreign_section], [@page, foreign_section]].each do |page, section|
      assert_no_difference "Section.count" do
        delete admin_page_section_path(page, section)
      end
      assert_response :not_found
    end
  end

  test "full editor and card deletion use forms with safe redirects" do
    get edit_admin_page_section_path(@page, @section)
    assert_select "form[action='#{admin_page_section_path(@page, @section, locale: 'pt-BR')}'] input[name='_method'][value='delete']"
    card = @section.section_items.create!(title: "Card")
    get admin_page_section_section_items_path(@page, @section)
    assert_select "form[action='#{admin_page_section_section_item_path(@page, @section, card, locale: 'pt-BR')}'] input[name='_method'][value='delete']"
    delete admin_page_section_section_item_path(@page, @section, card)
    assert_response :see_other
    follow_redirect!
    assert_response :success
    assert_not SectionItem.exists?(card.id)
  end
end
