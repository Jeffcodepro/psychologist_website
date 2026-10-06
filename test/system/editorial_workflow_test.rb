require "application_system_test_case"
require "minitest/mock"

Selenium::WebDriver.logger.level = :warn

class EditorialWorkflowTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1440, 1100]

  setup do
    @tenant = Tenant.create!(name: "Escrita", slug: "escrita-browser", primary: true)
    @tenant.create_site_setting!(professional_name: "Autora")
    @user = @tenant.users.create!(admin: true, email: "writing-browser@example.test", password: "Writing-browser-123!")
    @content_page = @tenant.pages.create!(name: "Página de testes", slug: "testes")
    @first = @content_page.sections.create!(section_type: "text", title: "Primeira seção", body: "Primeiro parágrafo.\n\nSegundo parágrafo.", position: 1)
    @second = @content_page.sections.create!(section_type: "text", title: "Segunda seção", position: 2)
    login_as @user
  end

  teardown do
    Warden.test_reset!
    page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
  end

  test "drawer closes with X and Escape and can reopen inside preview iframe" do
    visit admin_page_preview_path(@content_page)
    within_frame(find('.admin-preview-device__iframe')) do
      find("[data-panel-id='preview-editor-#{@first.id}']").click
      within("#preview-editor-#{@first.id}") { find('button[aria-label="Fechar editor"]').click }
      assert_no_selector '.preview-editor-drawer'
      assert_no_selector '.preview-editor-backdrop'
      assert_no_selector 'body.preview-editor-is-open'
      find("[data-panel-id='preview-editor-#{@second.id}']").click
      assert_selector "#preview-editor-#{@second.id}"
      page.send_keys :escape
      assert_no_selector '.preview-editor-drawer'
      find("[data-panel-id='preview-editor-#{@first.id}']").click
      assert_selector "#preview-editor-#{@first.id}"
    end
  end

  test "real drag swaps sections through fetch without an error redirect" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    PagePublicationService.new(page: @content_page).call
    visit admin_page_preview_frame_path(@content_page)
    handle = find(".preview-drag-handle[data-section-id='#{@second.id}']")
    handle.drag_to(find(".preview-editable-section[data-section-id='#{@first.id}'] .preview-editable-section__name"))
    assert_selector '.preview-editable-section:first-child .section-heading', text: 'Segunda seção'
    assert_equal [@second.id, @first.id], @content_page.sections.draft.ordered.pluck(:id)
    assert_equal 'Primeira seção', @content_page.sections.published.ordered.first.title
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  test "writer formats translates saves and reopens the complete article" do
    visit new_admin_article_path
    fill_in 'Título do texto', with: 'Comunicação assertiva'
    fill_in 'Texto completo', with: 'Comunicação Assertiva'
    input = find('#article_content_body')
    input.execute_script('this.setSelectionRange(0, this.value.length)')
    within('.article-writing-form__body') do
      find('button[aria-label="Negrito"]').click
      assert_field 'Texto completo', with: '**Comunicação Assertiva**'
      click_button 'Ver formatação'
      assert_selector '.formatted-text__preview strong', text: 'Comunicação Assertiva'
      click_button 'Voltar a escrever'
    end
    find('summary', text: 'Versão em inglês', exact_text: true).click
    result = Object.new
    result.define_singleton_method(:call) { { title_en: 'Assertive communication', body_en: '**Assertive Communication**' } }
    TranslationService.stub(:new, ->(**) { result }) do
      click_button 'Traduzir com IA'
      assert_field 'Texto completo em inglês', with: '**Assertive Communication**'
    end
    click_button 'Salvar rascunho'
    assert_text 'Texto salvo em rascunho'
    article = @tenant.pages.editorial.last
    assert_current_path edit_admin_article_path(article)
    assert_field 'Texto completo', with: '**Comunicação Assertiva**'
    assert_no_field 'Exibir na menu'
    assert_equal '**Comunicação Assertiva**', article.sections.draft.find_by!(section_type: 'text').body
    assert_equal 'Assertive communication', article.sections.draft.find_by!(section_type: 'hero').title_en
    save_screenshot(Rails.root.join('output/playwright/article-writing-127.png'))
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 390, height: 950, deviceScaleFactor: 1, mobile: false)
    assert_operator page.evaluate_script('document.documentElement.scrollWidth'), :<=, 391
    save_screenshot(Rails.root.join('output/playwright/article-writing-mobile-127.png'))
  end

  test "spacing preview shows unsaved desktop and mobile spacing with the actual content" do
    visit edit_admin_page_section_path(@content_page, @first)
    find('[data-tab="appearance"]').click
    fill_in "layout_#{@first.id}_desktop_title_body_gap", with: '72'
    assert_text 'Prévia atualizada. Nada foi salvo ainda.'
    within_frame(find('iframe[title="Prévia de espaçamento · desktop"]')) do
      assert_selector '.section-body', text: 'Primeiro parágrafo.'
      assert_selector '[style*="--desktop-title-body-gap: 72px"]'
      gap = page.evaluate_script("document.querySelector('.preview-movable--body').getBoundingClientRect().top - document.querySelector('.preview-movable--title').getBoundingClientRect().bottom")
      assert_in_delta 72, gap, 1
    end
    assert_nil @first.reload.title_body_gap
    find('.spacing-live').execute_script("this.scrollIntoView({block: 'start', behavior: 'instant'}); window.scrollBy({top: -100, behavior: 'instant'})")
    save_screenshot(Rails.root.join('output/playwright/spacing-preview-127.png'))
    find('[data-device-appearance-target="button"][data-device="mobile"]').click
    fill_in "layout_#{@first.id}_mobile_title_body_gap", with: '21'
    assert_text 'Prévia atualizada. Nada foi salvo ainda.'
    within_frame(find('iframe[title="Prévia de espaçamento · mobile"]')) do
      assert_selector '[style*="--mobile-title-body-gap: 21px"]'
      gap = page.evaluate_script("document.querySelector('.preview-movable--body').getBoundingClientRect().top - document.querySelector('.preview-movable--title').getBoundingClientRect().bottom")
      assert_in_delta 21, gap, 1
    end
    assert_nil @first.reload.title_body_gap
    assert_empty @first.responsive_settings
  end

  test "all saved pages can be published from one review screen" do
    visit admin_page_preview_path(@content_page)
    click_link 'Publicar site…'
    assert_text 'Somente rascunhos já salvos serão publicados.'
    accept_confirm { click_button 'Publicar páginas selecionadas' }
    assert_text 'páginas publicadas com sucesso.'
    assert @content_page.reload.published?
    assert_equal 2, @content_page.sections.published.count
  end
end
