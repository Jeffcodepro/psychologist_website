require "application_system_test_case"

Selenium::WebDriver.logger.level = :warn

class BlockDeletionTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  setup do
    @tenant = Tenant.create!(name: "Exclusão", slug: "exclusao", primary: true)
    @tenant.create_site_setting!(professional_name: "Exclusão")
    login_as @tenant.users.create!(admin: true, email: "delete@example.test", password: "Deletion-test-password-123!")
    @content_page = @tenant.pages.create!(name: "Página de teste", slug: "pagina-de-teste")
    @section = @content_page.sections.create!(section_type: "text", title: "Bloco para excluir", position: 1)
    @remaining = @content_page.sections.create!(section_type: "text", title: "Bloco preservado", position: 2)
    PagePublicationService.new(page: @content_page).call
  end

  teardown { Warden.test_reset! }

  test "deleting through the preview drawer keeps the preview and published content" do
    visit admin_page_preview_path(@content_page, locale: :en)
    within_frame(find(".admin-preview-device__iframe")) do
      find("[data-panel-id='preview-editor-#{@section.id}']").click
      page.execute_script("window.frameElement.scrollIntoView({block: 'end', behavior: 'instant'})")
      within("#preview-editor-#{@section.id}") do
        accept_confirm { click_on "Excluir bloco" }
      end
      assert_no_selector "[data-preview-section-id='#{@section.id}']"
      assert_selector "[data-preview-section-id='#{@remaining.id}']"
      assert_no_selector ".admin-navbar"
    end
    assert_current_path admin_page_preview_path(@content_page)
    assert_not Section.exists?(@section.id)
    assert_equal 1, @remaining.reload.position
    assert_equal 2, @content_page.sections.published.count
  end

  test "cancelling preview deletion leaves the block available for editing" do
    visit admin_page_preview_path(@content_page)
    within_frame(find(".admin-preview-device__iframe")) do
      find("[data-panel-id='preview-editor-#{@section.id}']").click
      page.execute_script("window.frameElement.scrollIntoView({block: 'end', behavior: 'instant'})")
      within("#preview-editor-#{@section.id}") do
        dismiss_confirm { click_on "Excluir bloco" }
        assert_selector "button", text: "Salvar rascunho"
      end
      assert_selector "[data-preview-section-id='#{@section.id}']"
    end
    assert Section.exists?(@section.id)
  end

  test "deleting the last preview block keeps an editable page" do
    @remaining.destroy!
    visit admin_page_preview_path(@content_page)
    within_frame(find(".admin-preview-device__iframe")) do
      find("[data-panel-id='preview-editor-#{@section.id}']").click
      page.execute_script("window.frameElement.scrollIntoView({block: 'end', behavior: 'instant'})")
      within("#preview-editor-#{@section.id}") do
        accept_confirm { click_on "Excluir bloco" }
      end
      assert_selector ".preview-live-editor"
      assert_no_selector ".preview-editable-section"
    end
    assert_selector ".admin-preview-header", text: "Editar conteúdo"
    assert_equal 0, @content_page.sections.draft.count
  end

  test "deleting from the full editor returns to the block list" do
    visit edit_admin_page_section_path(@content_page, @section)
    accept_confirm { click_on "Excluir bloco" }
    assert_current_path admin_page_sections_path(@content_page)
    assert_text "Bloco removido."
    assert_not Section.exists?(@section.id)
    assert_text "Bloco preservado"
  end
end
