require "application_system_test_case"

class ContactValidationBrowserTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1200, 1000]

  setup do
    @tenant = Tenant.create!(name: "Contato", slug: "validated-browser", primary: true)
    @tenant.create_site_setting!(professional_name: "Rosemary Dias")
    @content_page = TenantProvisioner.ensure_contact_page!(@tenant)
    @form = @content_page.sections.published.first
    @user = @tenant.users.create!(admin: true, email: "validation-editor@example.test", password: "Validation-test-password-123!")
  end

  teardown do
    Warden.test_reset!
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.current_window.resize_to(1200, 1000)
  end

  def input_id(key) = "contact_#{@form.id}_#{key}"

  test "country search keyboard selection and international paste validate before Turbo submission" do
    visit contact_path
    assert_selector '.contact-phone .ts-control', text: '🇧🇷 +55'
    fill_in input_id('full_name'), with: 'Ana'
    fill_in input_id('email'), with: 'ana@localhost'
    fill_in input_id('phone'), with: '12'
    fill_in input_id('message'), with: 'Quero conversar.'
    assert_selector '[data-field-error]', text: 'nome e sobrenome'
    assert_selector '[data-field-error]', text: 'e-mail válido'
    assert_selector '[data-field-error]', text: 'país selecionado'
    assert_equal 0, @tenant.contact_requests.count
    choose_select_option(find("##{input_id('phone')}_country", visible: :all), '🇵🇹 Portugal (+351)')
    fill_in input_id('phone'), with: '912 345 678'
    fill_in input_id('full_name'), with: 'Ana Silva'
    fill_in input_id('email'), with: 'ana+site@example.test'
    fill_in input_id('phone'), with: '+44 20 7946 0018'
    assert_selector '.contact-phone .ts-control', text: '🇬🇧 +44'
    fill_in input_id('message'), with: 'Mensagem de teste internacional.'
    assert_no_selector '[data-field-error]', visible: true
    click_button 'Quero agendar uma conversa'
    assert_selector '.appointment-form__success', text: 'Mensagem recebida'
    assert_equal '+442079460018', @tenant.contact_requests.last.phone
  end

  test "country menu scrolls internally without moving or locking the page on desktop and mobile" do
    [1200, 390].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
      visit contact_path
      control = find('.contact-phone .ts-control')
      control.click
      menu = page.document.find('.selection-menu', visible: true)
      list = menu.find('.ts-dropdown-content')
      assert_operator list.evaluate_script('this.scrollHeight'), :>, list.evaluate_script('this.clientHeight')
      position = page.evaluate_script('window.scrollY')
      before = list.evaluate_script('this.scrollTop')
      origin = Selenium::WebDriver::WheelActions::ScrollOrigin.element(list.native)
      page.driver.browser.action.scroll_from(origin, 0, 240).perform
      Selenium::WebDriver::Wait.new(timeout: 3).until { list.evaluate_script('this.scrollTop') > before }
      assert_in_delta position, page.evaluate_script('window.scrollY'), 1
      assert menu.visible?
      search = menu.find('.dropdown-input')
      search.set('Portugal')
      search.send_keys(:arrow_down, :enter)
      assert_selector '.contact-phone .ts-control', text: '🇵🇹 +351'
      assert_no_selector '.selection-menu', visible: true
      control.click
      page.document.find('.selection-menu .dropdown-input', visible: true).send_keys(:escape)
      assert_no_selector '.selection-menu', visible: true
      assert page.evaluate_script('getComputedStyle(document.body).overflowY !== "hidden"')
      FileUtils.mkdir_p(Rails.root.join('output/playwright'))
      save_screenshot(Rails.root.join("output/playwright/contact-validation-#{width}.png"))
    end
  end

  test "dynamic form designer selects update the saved schema and survive Turbo navigation" do
    login_as @user
    draft = @content_page.sections.draft.first
    visit edit_admin_page_section_path(@content_page, draft)
    # The form designer is on the content tab.
    find('[data-section-form-tabs-target="tab"][data-tab="contact_fields"]').click
    click_button '+ Adicionar campo'
    row = all('[data-field-row]').last
    within row do
      fill_in 'Nome do campo', with: 'Nome do responsável'
      choose_select_option(find('[data-property="type"]', visible: :all), 'Nome e sobrenome')
    end
    click_button 'Salvar alterações'
    assert_text 'Rascunho salvo.'
    assert_equal 'name', draft.reload.form_fields.last['type']
    visit edit_admin_page_section_path(@content_page, draft)
    find('[data-section-form-tabs-target="tab"][data-tab="contact_fields"]').click
    assert_selector '[data-field-row] .ts-control', text: 'Nome e sobrenome'
    assert_no_selector '.selection-control .selection-control'
  end
end
