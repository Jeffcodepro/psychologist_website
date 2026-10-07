require "application_system_test_case"
require "vips"

Selenium::WebDriver.logger.level = :warn

class ImagePresentationTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1440, 1100]

  setup do
    @tenant = Tenant.create!(name: "Imagens", slug: "image-presentation", primary: true)
    @settings = @tenant.create_site_setting!(professional_name: "Marca de teste")
    @user = @tenant.users.create!(admin: true, email: "presentation@example.test", password: "Presentation-test-123!")
    @content_page = @tenant.pages.create!(name: "Imagens", slug: "imagens")
    @section = @content_page.sections.create!(section_type: "text", title: "Foto em destaque", body: "Uma imagem integrada ao conteúdo.")
    bytes = Vips::Image.black(400, 500).new_from_image([78, 130, 100, 255]).write_to_buffer(".png")
    @section.image.attach(io: StringIO.new(bytes), filename: "photo.png", content_type: "image/png")
    @settings.logo.attach(io: StringIO.new(bytes), filename: "logo.png", content_type: "image/png")
    login_as @user
  end

  teardown do
    Warden.test_reset!
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "logo hit area follows visible image on desktop and mobile without changing the frame" do
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    assert_selector '.site-navbar__logo-link[aria-label="Marca de teste — Página inicial"]'
    [1440, 390].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 950, deviceScaleFactor: 1, mobile: false)
      logo = find('.site-navbar__logo-link')
      # ResizeObserver updates after the viewport change has been painted.
      assert_selector '.site-navbar__logo-link[style*="width:"]' do |candidate|
        candidate.evaluate_script('Math.abs(this.getBoundingClientRect().width - this.parentElement.clientHeight * 0.8) <= 1')
      end
      bounds = logo.evaluate_script("({link: this.getBoundingClientRect().width, frame: this.parentElement.clientWidth, height: this.parentElement.clientHeight})")
      assert_in_delta bounds['height'] * 0.8, bounds['link'], 1
      assert_operator bounds['link'], :<, bounds['frame'] / 2
      assert logo.evaluate_script("(() => { const r = this.parentElement.getBoundingClientRect(); return !document.elementFromPoint(r.left + 2, r.top + r.height / 2).closest('a') })()")
    end
    @settings.update!(logo_zoom: 0.5, logo_position_x: 0)
    visit public_page_path(slug: @content_page.slug)
    logo = find('.site-navbar__logo-link[style*="width:"]')
    assert_in_delta 16.8, logo.evaluate_script('this.getBoundingClientRect().width'), 1
    logo.click
    assert_current_path root_path
  end

  test "cutout preset and zoom out match saved public photo and responsive settings" do
    visit edit_admin_page_section_path(@content_page, @section)
    find('[data-tab="media"]').click
    cropper = find('[data-image-cropper-kind-value="image"][data-image-cropper-shape-field-value="section[image_shape]"]')
    cropper.execute_script("this.scrollIntoView({block:'center', behavior:'instant'})")
    within(cropper) do
      assert_selector '[data-image-cropper-target="dimensions"]', text: '400 × 500'
      click_button 'Aplicar efeito foto recortada'
      set_range('zoom', 0.5)
      set_range('x', 80)
      assert_equal '0.5', find('[data-image-cropper-target="zoom"]').value
      image = find('[data-image-cropper-target="image"]')
      assert_equal 'contain', image.evaluate_script('getComputedStyle(this).objectFit')
      assert_includes image.evaluate_script('getComputedStyle(this).filter'), 'drop-shadow'
      frame = find('[data-image-cropper-target="frame"]')
      frame.execute_script("this.scrollIntoView({block:'center', behavior:'instant'})")
      page.driver.browser.action.move_to(frame.native).click_and_hold.move_by(-25, 0).release.perform
      assert_operator find('[data-image-cropper-target="x"]').value.to_f, :<, 80
      assert_equal '0.5', find('[data-image-cropper-target="zoom"]').value
      frame.execute_script("this.closest('.image-cropper').scrollIntoView({block:'start', behavior:'instant'})")
    end
    save_screenshot(Rails.root.join('output/playwright/image-presentation-editor.png'))
    click_button 'Salvar alterações'
    assert_text 'Rascunho salvo.'
    assert_equal 'cutout', @section.reload.image_shape
    assert_equal 0.5, @section.image_zoom
    assert_equal 'contain', @section.media_adjustment('image', 'fit')
    assert_equal '24', @section.media_adjustment('image', 'shadow')
    @section.update!(responsive_settings: { mobile: { image_zoom: 0.35, image_shape: 'rounded' } })
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    image = find('.flexible-section__image-frame .media-sequence__image')
    assert_equal 'contain', image.evaluate_script('getComputedStyle(this).objectFit')
    assert_match(/matrix\(0\.5, 0, 0, 0\.5/, image.evaluate_script('getComputedStyle(this).transform'))
    assert_equal 'visible', find('.flexible-section__image-frame').evaluate_script('getComputedStyle(this).overflow')
    assert_includes image.evaluate_script('getComputedStyle(this).filter'), '0.24'
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 390, height: 950, deviceScaleFactor: 1, mobile: false)
    assert_match(/matrix\(0\.35, 0, 0, 0\.35/, image.evaluate_script('getComputedStyle(this).transform'))
    assert_equal 'hidden', find('.flexible-section__image-frame').evaluate_script('getComputedStyle(this).overflow')
    assert_operator page.evaluate_script('document.documentElement.scrollWidth'), :<=, 391
  end

  test "showing a whole card image keeps card dimensions and restores controls on reopening" do
    @section.update!(section_type: 'cards')
    card = @section.section_items.create!(title: 'Card com foto', image: @section.image.blob)
    visit edit_admin_page_section_section_item_path(@content_page, @section, card)
    select 'Mostrar a imagem inteira', from: 'Como encaixar a foto'
    set_range('zoom', 0.4)
    set_range('y', 85)
    original_height = find('.compact-card').evaluate_script('this.getBoundingClientRect().height')
    assert_equal '0.4', find('[data-image-cropper-target="zoom"]').value
    click_button 'Salvar card'
    assert_text 'Conteúdo atualizado com sucesso.'
    assert_equal BigDecimal('0.4'), card.reload.image_zoom
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    assert_in_delta original_height, find('.compact-card').evaluate_script('this.getBoundingClientRect().height'), 1
    image = find('.compact-card__image')
    assert_equal 'contain', image.evaluate_script('getComputedStyle(this).objectFit')
    assert_equal '50% 85%', image.evaluate_script('getComputedStyle(this).objectPosition')
    assert_match(/matrix\(0\.4, 0, 0, 0\.4/, image.evaluate_script('getComputedStyle(this).transform'))
  end

  test "background preview is reversible and only updates the form after a successful load" do
    visit edit_admin_page_section_path(@content_page, @section)
    find('[data-tab="media"]').click
    cropper = find('[data-image-cropper-kind-value="image"][data-image-cropper-shape-field-value="section[image_shape]"]')
    cropper.execute_script("this.scrollIntoView({block:'center', behavior:'instant'})")
    within(cropper) do
      find('summary', text: 'Remover fundo com IA').click
      assert_button 'Remover fundo', disabled: true
      # Substitute only the external processing result with a local fixture; no credits or external requests.
      cropper.execute_script("const c = window.Stimulus.getControllerForElementAndIdentifier(this, 'image-cropper'); c.cutoutUrlValue = c.originalUrlValue; c.backgroundButtonTarget.disabled = false")
      click_button 'Remover fundo'
      assert_button 'Restaurar fundo original', disabled: false
      assert_equal '1', find('[data-adjustment="remove_background"]', visible: :all).value
      assert_equal({}, @section.reload.media_adjustments)
      click_button 'Restaurar fundo original'
      assert_equal '0', find('[data-adjustment="remove_background"]', visible: :all).value
      assert_button 'Remover fundo', disabled: false
    end
  end

  private

  def set_range(target, value)
    find("[data-image-cropper-target='#{target}']", visible: :all).execute_script("this.value=arguments[0]; this.dispatchEvent(new Event('input', {bubbles:true}))", value)
  end
end
