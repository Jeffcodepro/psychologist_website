require "application_system_test_case"
require "base64"
require "minitest/mock"

Selenium::WebDriver.logger.level = :warn

class MediaOverlaysAndTranslationTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1100]

  setup do
    @tenant = Tenant.create!(name: "Mídia", slug: "media-overlay", primary: true)
    @tenant.create_site_setting!(professional_name: "Mídia")
    TenantProvisioner.ensure_contact_page!(@tenant)
    @user = @tenant.users.create!(admin: true, email: "overlay-browser@example.test", password: "Media-browser-password-123!")
    @content_page = @tenant.pages.create!(name: "Mídia", slug: "midia")
    @section = @content_page.sections.create!(section_type: "hero", title: "Conheça meu trabalho", body: "Uma imagem, diversas possibilidades.",
      banner_layout: "background", banner_overlay: 35, overlay_color: "#314f3e",
      action_buttons: [{ label: "Primeiro", label_en: "First", action: "contact", style: "secondary" }])
    image = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=")
    @section.banner.attach(io: StringIO.new(image), filename: "overlay.png", content_type: "image/png")
    @section.image.attach(@section.banner.blob)
    login_as @user
  end

  teardown do
    Warden.test_reset!
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "new buttons translate only their own label and keep it after reorder save and publication" do
    visit edit_admin_page_section_path(@content_page, @section)
    find('[data-tab="buttons"]').click
    click_button "+ Adicionar botão"
    row = all('[data-button-row]').last
    row.find('[data-property="label"]').set("Conheça meu trabalho")
    row.find('summary', text: "Texto em inglês").click
    assert_equal "", row.find('[data-property="label_en"]').value
    factory = ->(title:, body:) do
      assert_equal "Conheça meu trabalho", title
      assert_equal "", body
      Struct.new(:result) { def call = result }.new({ title_en: "Explore my work", body_en: "" })
    end
    TranslationService.stub(:new, factory) do
      row.click_button "Traduzir com IA"
      assert_selector '[data-button-row] .is-success', text: "Versão em inglês gerada"
    end
    assert_equal "Explore my work", row.find('[data-property="label_en"]').value
    row.find('[data-action="button-designer#up"]').click
    click_button "Salvar alterações"
    assert_text "Rascunho salvo."
    assert_equal ["Explore my work", "First"], @section.reload.action_buttons.map { |button| button["label_en"] }
    assert_equal "Uma imagem, diversas possibilidades.", @section.body
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    find('form.site-language-form button', text: 'EN', exact_text: true, match: :first).click
    assert_selector '.site-action', text: 'Explore my work'
    assert_equal "Explore my work", @content_page.sections.published.first.action_buttons.first["label_en"]
    login_as @user
    visit edit_admin_page_section_path(@content_page, @section)
    find('[data-tab="buttons"]').click
    find('[data-button-row]', match: :first).find('summary').click
    save_screenshot(Rails.root.join("output/playwright/button-ai-126.png"))
  end

  test "preview translates button and section separately without mixing their fields" do
    visit admin_page_preview_frame_path(@content_page)
    find("[data-panel-id='preview-editor-#{@section.id}']").click
    within "#preview-editor-#{@section.id}" do
      factory = ->(title:, body:) { Struct.new(:result) { def call = result }.new({ title_en: "Translated: #{title}", body_en: body.empty? ? "" : "Translated body" }) }
      TranslationService.stub(:new, factory) do
        click_button "Gerar versão em inglês"
        assert_selector '.section-content-editor .is-success', text: "Versão em inglês gerada"
        assert_equal "Translated body", find('[name="section[body_en]"]').value
        find('[data-tab="buttons"]').click
        find('[data-button-row] summary').click
        click_button "Traduzir com IA"
        assert_selector '.button-designer .is-success', text: "Versão em inglês gerada"
        assert_equal "Translated: Primeiro", find('[data-property="label_en"]').value
      end
      click_button "Salvar rascunho"
    end
    assert_selector '[data-section-frame-id]'
    assert_equal "Translated body", @section.reload.body_en
    assert_equal "Translated: Primeiro", @section.action_buttons.first['label_en']
  end

  test "translation errors preserve English and changed text cannot be overwritten by a late response" do
    visit edit_admin_page_section_path(@content_page, @section)
    find('[data-tab="buttons"]').click
    row = find('[data-button-row]')
    row.find('summary').click
    service = Object.new
    def service.call = raise TranslationService::Error, "A tradução atingiu o limite da API."
    TranslationService.stub(:new, ->(**) { service }) do
      row.click_button "Traduzir com IA"
      assert_selector '.button-designer .is-error', text: "limite da API"
      assert_equal "First", row.find('[data-property="label_en"]').value
    end
    page.execute_script("window.originalFetch = window.fetch; window.fetch = () => new Promise(resolve => { window.finishTranslation = () => resolve({ok: true, json: async () => ({title_en: 'Old translation', body_en: ''})}) })")
    row.click_button "Traduzir com IA"
    assert_button "Traduzindo…", disabled: true
    row.find('[data-property="label"]').set("Texto novo durante a tradução")
    page.execute_script("window.finishTranslation(); window.fetch = window.originalFetch")
    assert_selector '.button-designer .is-error', text: "O texto mudou"
    assert_equal "First", row.find('[data-property="label_en"]').value
    assert_button "Traduzir com IA", disabled: false
  end

  test "preview editor renders a compact photo checkbox and a working banner select" do
    visit admin_page_preview_frame_path(@content_page)
    find("[data-panel-id='preview-editor-#{@section.id}']").click
    within "#preview-editor-#{@section.id}" do
      find('[data-tab="media"]').click
      checkbox = find('.cms-toggle input[type="checkbox"]')
      assert_equal [20, 20], checkbox.evaluate_script('[this.getBoundingClientRect().width, this.getBoundingClientRect().height]')
      assert_equal "flex", find('.cms-toggle').evaluate_script('getComputedStyle(this).display')
      check "Usar a foto profissional nesta seção"
      select "Faixa abaixo", from: "Onde exibir o banner"
      assert_selector '.ts-control .item', text: "Faixa abaixo"
      checkbox.execute_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
      save_screenshot(Rails.root.join("output/playwright/media-toggle-126.png"))
      page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 390, height: 950, deviceScaleFactor: 1, mobile: false)
      assert_equal [20, 20], checkbox.evaluate_script('[this.getBoundingClientRect().width, this.getBoundingClientRect().height]')
      assert find('.cms-toggle').evaluate_script('this.getBoundingClientRect().right <= document.documentElement.clientWidth')
      checkbox.execute_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
      save_screenshot(Rails.root.join("output/playwright/media-toggle-mobile-126.png"))
      click_button "Salvar rascunho"
    end
    assert_selector '[data-section-frame-id]'
    assert @section.reload.use_profile_image?
    assert_equal "bottom", @section.banner_layout
  end

  test "overlay controls preview and save independent desktop and mobile colors and intensity" do
    visit edit_admin_page_section_path(@content_page, @section)
    find('[data-tab="media"]').click
    fill_in "overlay_#{@section.id}_banner_desktop_color", with: "#c08020"
    fill_in "overlay_#{@section.id}_banner_desktop_opacity", with: "20"
    fill_in "overlay_#{@section.id}_image_desktop_color", with: "#204080"
    fill_in "overlay_#{@section.id}_image_desktop_opacity", with: "55"
    assert_equal ['rgb(192, 128, 32)', '0.2'], sample_metrics('banner')
    assert_equal ['rgb(32, 64, 128)', '0.55'], sample_metrics('image')
    find('[data-media-overlay-role-value="image"]').execute_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
    save_screenshot(Rails.root.join('output/playwright/image-overlay-126.png'))
    within '[data-media-overlay-role-value="image"]' do
      click_button "Mobile"
      assert_equal ['rgb(32, 64, 128)', '0.55'], sample_metrics('image')
      fill_in "overlay_#{@section.id}_image_mobile_opacity", with: "0"
      assert_equal ['rgb(32, 64, 128)', '0'], sample_metrics('image')
    end
    click_button "Salvar alterações"
    assert_text "Rascunho salvo."
    assert_equal "55", @section.reload.image_overlay_opacity
    assert_equal "0", @section.responsive_settings.dig("mobile", "image_overlay_opacity")
    visit admin_page_preview_frame_path(@content_page)
    assert_equal ['rgb(192, 128, 32)', '0.2', 'rgb(32, 64, 128)', '0.55'], page_overlay_metrics
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    assert_equal ['rgb(192, 128, 32)', '0.2', 'rgb(32, 64, 128)', '0.55'], page_overlay_metrics
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 390, height: 950, deviceScaleFactor: 1, mobile: false)
    assert_equal ['rgb(192, 128, 32)', '0.2', 'rgb(32, 64, 128)', '0'], page_overlay_metrics
    assert_equal '1', find('.section-heading').evaluate_script('getComputedStyle(this).opacity')
  end

  test "banner strips and image backgrounds honor full and zero overlay in every viewport" do
    @section.update!(banner_overlay_color: "#204080", banner_overlay_opacity: 100, image_overlay_color: "#c08020", image_overlay_opacity: 0, media_layout: "media_background")
    %w[top background bottom].each do |position|
      @section.update!(banner_layout: position)
      PagePublicationService.new(page: @content_page).call
      logout
      visit public_page_path(slug: @content_page.slug)
      [1400, 800, 390].each do |width|
        page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: width, height: 1100, deviceScaleFactor: 1, mobile: false)
        assert_equal ['rgb(32, 64, 128)', '1', 'rgb(192, 128, 32)', '0'], page_overlay_metrics
        assert_equal 'block', find('.section-frame__overlay', visible: :all).evaluate_script('getComputedStyle(this).display')
      end
    end
  end

  private

  def sample_metrics(role)
    page.document.find("[data-media-overlay-role-value='#{role}'] [data-overlay-sample]", visible: true).evaluate_script("[getComputedStyle(this, '::after').backgroundColor, getComputedStyle(this, '::after').opacity]")
  end

  def page_overlay_metrics
    page.evaluate_script(<<~JS)
      (() => {
        const banner = getComputedStyle(document.querySelector('.section-frame__overlay'));
        const image = getComputedStyle(document.querySelector('.flexible-section__image-frame'), '::after');
        return [banner.backgroundColor, banner.opacity, image.backgroundColor, image.opacity];
      })()
    JS
  end
end
