require "application_system_test_case"

class EditorRefinementsTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup do
    @tenant = Tenant.create!(name: "Design", slug: "design", primary: true)
    @tenant.create_site_setting!(professional_name: "Rosemary Dias")
    @user = @tenant.users.create!(admin: true, email: "design@example.test", password: "Design-test-password-123!")
    @content_page = @tenant.pages.create!(name: "Contato", slug: "contato")
    @section = @content_page.sections.create!(section_type: "contact", title: "Vamos conversar", body: "Primeiro parágrafo.\n\nSegundo parágrafo.",
      form_position: "right", content_gap: 38, paragraph_spacing: 25, section_padding_top: 60, column_gap: 50,
      responsive_settings: { mobile: { content_gap: 14, paragraph_spacing: 10 } })
    PagePublicationService.new(page: @content_page).call
  end

  teardown do
    Warden.test_reset!
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.current_window.resize_to(1400, 1000)
  end

  test "contact position and spacing match the selected screen and remain editable in preview" do
    visit contact_path
    assert_selector '.flexible-section__form form'
    assert page.evaluate_script(<<~JS)
      (() => {
        const layout = document.querySelector('.flexible-section__layout').getBoundingClientRect();
        const form = document.querySelector('.flexible-section__form').getBoundingClientRect();
        return layout.right <= form.left && Math.abs(layout.top - form.top) < 2;
      })()
    JS
    assert_equal '38px', find('.flexible-section__copy').evaluate_script('getComputedStyle(this).gap')
    assert_equal '25px', find('.section-body p + p').evaluate_script('getComputedStyle(this).marginTop')
    capture('contact-desktop')
    mobile
    visit contact_path
    assert find('.flexible-section__form').evaluate_script('this.getBoundingClientRect().top >= document.querySelector(".flexible-section__layout").getBoundingClientRect().bottom')
    assert_equal '14px', find('.flexible-section__copy').evaluate_script('getComputedStyle(this).gap')
    assert_equal '10px', find('.section-body p + p').evaluate_script('getComputedStyle(this).marginTop')
    capture('contact-mobile')
    login_as @user
    visit admin_page_preview_frame_path(@content_page)
    find('[data-move-field="form"]').click
    find('[data-position="top"]').click
    assert_selector '[data-visual-drag-target="status"]', text: 'Posição salva'
    assert_equal 'before_text', @section.reload.visual_value('form_position', 'mobile')
    assert_equal 'right', @section.form_position
    assert find('.flexible-section__form').evaluate_script('this.getBoundingClientRect().bottom <= document.querySelector(".flexible-section__layout").getBoundingClientRect().top')
  end

  test "multiple SEO choices leave existing text intact until applied" do
    login_as @user
    @content_page.update!(seo_title: 'Meu título')
    visit edit_admin_page_path(@content_page)
    within('.seo-editor', match: :first) do
      assert_selector '[data-seo-editor-target="template"] option', count: 4, visible: :all
      select 'Nome em primeiro plano', from: 'Modelo de apresentação'
      assert_field 'Título SEO', with: 'Meu título'
      click_button 'Aplicar modelo'
      assert_field 'Título SEO', with: 'Rosemary Dias — Contato'
      assert_selector '[data-seo-editor-target="previewTitle"]', text: 'Rosemary Dias — Contato'
      capture('seo-models')
    end
    assert_equal 'Meu título', @content_page.reload.seo_title
  end

  test "font choices use compact controls without expanding the typography panel" do
    login_as @user
    visit edit_admin_page_section_path(@content_page, @section)
    find('[data-device-appearance-target="button"][data-device="desktop"]').click if has_selector?('[data-device-appearance-target="button"][data-device="desktop"]')
    find('[data-section-form-tabs-target="tab"][data-tab="appearance"]').click
    picker = find('.font-picker', match: :first)
    original_height = picker.evaluate_script('this.getBoundingClientRect().height')
    choose_select_option(picker.find('select', visible: :all), 'DM Sans')
    assert_in_delta original_height, picker.evaluate_script('this.getBoundingClientRect().height'), 1
    assert_includes picker.find('.font-picker__sample').evaluate_script('getComputedStyle(this).fontFamily'), 'DM Sans'
    assert_no_selector '.font-picker details'
    assert_no_selector 'select.is-valid'
    assert_equal '10px', picker.find('.ts-control').evaluate_script('getComputedStyle(this).borderRadius')
    assert_no_selector '.selection-menu', visible: true
    capture('font-selector')
  end

  private
  def mobile
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 390, height: 1000, deviceScaleFactor: 1, mobile: false)
  end
  def capture(name)
    return unless ENV['CMS_VISUAL_QA'] == '1'
    FileUtils.mkdir_p(Rails.root.join('tmp/screenshots/refinements'))
    save_screenshot(Rails.root.join("tmp/screenshots/refinements/#{name}.png"))
  end
end
