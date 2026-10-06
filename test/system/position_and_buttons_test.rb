require "application_system_test_case"
require "base64"

class PositionAndButtonsTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup do
    @tenant = Tenant.create!(name: 'Editor', slug: 'editor', primary: true)
    @tenant.create_site_setting!(professional_name: 'Editor')
    @user = @tenant.users.create!(admin: true, email: 'editor-buttons@example.test', password: 'Editor-buttons-password-123!')
    @content_page = @tenant.pages.create!(name: 'Conteúdo', slug: 'conteudo')
    @section = @content_page.sections.create!(section_type: 'text_image', title: 'Texto de exemplo', body: 'Descrição do trabalho.')
    image = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=')
    @section.image.attach(io: StringIO.new(image), filename: 'sample.png', content_type: 'image/png')
    PagePublicationService.new(page: @content_page).call
    login_as @user
  end

  teardown do
    Warden.test_reset!
    page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
  end

  test 'position choices occupy the expected direction on mobile and desktop and right moves the image right' do
    [1400, 390].each do |width|
      page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
      visit admin_page_preview_frame_path(@content_page)
      find('[data-move-field="image"]').click
      zones = find('[data-visual-drag-target="zones"]')
      assert zones.evaluate_script(<<~JS)
        (() => {
          const rect = key => this.querySelector(`[data-position="${key}"]`).getBoundingClientRect();
          return rect('left').right < rect('right').left && rect('top').bottom < rect('left').top && rect('bottom').top > rect('right').bottom;
        })()
      JS
      assert_selector '[data-position="right"] .element-drop-zone__diagram'
      capture("positions-#{width}")
      zones.find('[data-position="right"]').click
      assert_selector '[data-visual-drag-target="status"]', text: 'Posição salva'
      assert page.evaluate_script("document.querySelector('.flexible-section__media').getBoundingClientRect().left >= document.querySelector('.flexible-section__copy').getBoundingClientRect().right")
    end
  end

  test 'a customized button can be created from its dedicated tab and opens a section on the public page' do
    visit edit_admin_page_section_path(@content_page, @section)
    find('[data-tab="buttons"]').click
    click_button '+ Adicionar botão'
    within('[data-button-row]') do
      find('[data-property="label"]').set('Conheça a seção')
      select 'Seção de uma página', from: 'Ação'
      choose_select_option(find('[data-property="section_value"]', visible: :all), 'Conteúdo · Texto de exemplo')
      select 'Personalizado', from: 'Estilo'
      select 'Grande', from: 'Tamanho'
      select 'Arredondado', from: 'Formato'
      assert_selector '[data-button-sample].site-action--custom.site-action--large'
      capture('custom-buttons')
    end
    click_button 'Salvar alterações'
    assert_text 'Rascunho salvo.'
    assert_equal 'section', @section.reload.action_buttons.first['action']
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    assert_selector '.site-action--custom.site-action--rounded', text: 'Conheça a seção'
    click_link 'Conheça a seção'
    destination = public_page_path(slug: @content_page.slug, anchor: @section.navigation_anchor)
    assert_current_path(/#{Regexp.escape(destination)}\z/, url: true)
  end

  private
  def capture(name)
    return unless ENV['CMS_VISUAL_QA'] == '1'
    FileUtils.mkdir_p(Rails.root.join('tmp/screenshots/interaction'))
    save_screenshot(Rails.root.join("tmp/screenshots/interaction/#{name}.png"))
  end
end
