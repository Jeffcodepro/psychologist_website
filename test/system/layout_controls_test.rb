require 'application_system_test_case'
require 'base64'

class LayoutControlsTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup do
    @tenant = Tenant.create!(name: 'Controles', slug: 'controles', primary: true)
    @tenant.create_site_setting!(professional_name: 'Controles')
    @user = @tenant.users.create!(admin: true, email: 'controls@example.test', password: 'Control-layout-password-123!')
    @content_page = @tenant.pages.create!(name: 'Página', slug: 'pagina')
    @section = @content_page.sections.create!(section_type: 'cards', title: 'Áreas de atuação', body: 'Conheça nosso trabalho.', cards_wrap: false, cards_autoplay: false,
      action_buttons: [{ label: 'Fale conosco', action: 'contact', style: 'primary' }])
    5.times { |i| @section.section_items.create!(title: "Card #{i}", body: 'Um texto de apresentação.', position: i) }
    @form_page = @tenant.pages.create!(name: 'Contato', slug: 'contato')
    @form = @form_page.sections.create!(section_type: 'contact', title: 'Vamos conversar', body: 'Envie sua mensagem.', form_width: 'compact', form_position: 'right')
    PagePublicationService.new(page: @content_page).call
    PagePublicationService.new(page: @form_page).call
    login_as @user
  end

  teardown do
    Warden.test_reset!
    page.current_window.resize_to(1400, 1000)
  end

  test 'buttons move below the whole carousel and above it without losing text placements' do
    visit admin_page_preview_frame_path(@content_page)
    find('[data-move-field="buttons"]').click
    find('[data-position="after_cards"]').click
    assert_selector '[data-visual-drag-target="status"]', text: 'Posição salva'
    assert_equal 'after_cards', @section.reload.buttons_position
    assert_below_carousel
    @section.update!(responsive_settings: { mobile: { buttons_position: 'before_cards' } })
    %w[before after].each do |placement|
      @section.update!(cards_placement: placement)
      PagePublicationService.new(page: @content_page).call
      logout
      page.current_window.resize_to(1400, 1000)
      visit public_page_path(slug: @content_page.slug)
      assert_below_carousel
      assert_selector '.section-actions .site-action', count: 1
      page.current_window.resize_to(390, 900)
      assert find('.section-actions', visible: true).evaluate_script('this.getBoundingClientRect().bottom <= document.querySelector(".card-collection").getBoundingClientRect().top')
      assert_selector '.section-actions .site-action', count: 1
    end
  end

  test 'form drop zones place it below text at left center and right in preview and publication' do
    %w[left center right].each do |alignment|
      login_as @user
      visit admin_page_preview_frame_path(@form_page)
      find('[data-move-field="form"]').click
      position = alignment == 'center' ? 'bottom' : "bottom_#{alignment}"
      find("[data-position='#{position}']").click
      assert_selector '[data-visual-drag-target="status"]', text: 'Posição salva'
      assert_equal 'after_text', @form.reload.form_position
      assert_equal alignment, @form.form_alignment
      assert_form_below(alignment)
      PagePublicationService.new(page: @form_page).call
      logout
      visit contact_path
      assert_form_below(alignment)
    end
    save_screenshot(Rails.root.join('output/playwright/form-below-right-123.png'))
  end

  test 'form position map saves both placement and alignment and preserves device overrides' do
    visit edit_admin_page_section_path(@form_page, @form)
    find('[data-tab="appearance"]').click
    within '.form-placement-map', match: :first do
      click_button 'Abaixo · direita'
      assert_selector '[aria-pressed="true"][data-position="after_text"][data-alignment="right"]'
    end
    click_button 'Salvar alterações'
    assert_text 'Rascunho salvo.'
    assert_equal 'after_text', @form.reload.form_position
    assert_equal 'right', @form.form_alignment
    visit admin_page_preview_frame_path(@form_page)
    page.current_window.resize_to(390, 900)
    find('[data-move-field="form"]').click
    find('[data-position="top_left"]').click
    assert_selector '[data-visual-drag-target="status"]', text: 'Posição salva'
    assert_equal 'before_text', @form.reload.visual_value('form_position', 'mobile')
    assert_equal 'after_text', @form.form_position
  end

  test 'card overlay updates in the real preview and is identical after publication' do
    card = @section.section_items.first
    png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=')
    card.image.attach(io: StringIO.new(png), filename: 'overlay.png', content_type: 'image/png')
    card.update!(card_settings: { desktop: { image_layout: 'background' } })
    visit edit_admin_page_section_section_item_path(@content_page, @section, card)
    fill_in 'section_item_desktop_overlay_color', with: '#c08020'
    fill_in 'section_item_desktop_overlay_opacity', with: '20'
    fill_in 'section_item_desktop_background_text_color', with: '#132819'
    assert_equal ['rgb(192, 128, 32)', '0.2', 'rgb(19, 40, 25)'], tint_metrics
    fill_in 'section_item_desktop_overlay_opacity', with: '0'
    assert_equal '0', tint_metrics[1]
    find('.card-presentation summary', text: 'Mobile', exact_text: true).click
    fill_in 'section_item_mobile_overlay_opacity', with: '80'
    assert_equal '0.8', tint_metrics[1]
    click_button 'Salvar card'
    assert_text 'Conteúdo atualizado com sucesso.'
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    assert_equal ['rgb(192, 128, 32)', '0', 'rgb(19, 40, 25)'], tint_metrics
    page.current_window.resize_to(390, 900)
    assert_equal '0.8', tint_metrics[1]
  end

  test 'button editor keeps destination next to its action and compact colors with a live sample' do
    visit edit_admin_page_section_path(@content_page, @section)
    find('[data-tab="buttons"]').click
    within '[data-button-row]' do
      select 'Outra página', from: 'Ação'
      select 'Página', from: 'Página'
      select 'Personalizado', from: 'Estilo'
      select 'Pequeno', from: 'Tamanho'
      select 'Arredondado', from: 'Formato'
      find('[data-property="background_color"]').execute_script("this.value='#6a4030'; this.dispatchEvent(new Event('input', {bubbles: true}))")
      assert_selector '[data-color-value="background_color"]', text: '#6A4030'
      assert_selector '[data-button-sample].site-action--small.site-action--rounded'
      assert_operator find('[data-property="background_color"]').evaluate_script('this.getBoundingClientRect().width'), :<=, 40
      assert find('[data-property="page_value"]').evaluate_script('this.closest(".button-designer__content") !== null')
      find('[data-button-sample]').execute_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
      save_screenshot(Rails.root.join('output/playwright/button-editor-123.png'))
    end
    select 'Abaixo dos cards / carrossel', from: 'Posição dos botões'
    click_button 'Salvar alterações'
    assert_text 'Rascunho salvo.'
    assert_equal '#6a4030', @section.reload.action_buttons.first['background_color']
    assert_equal 'after_cards', @section.buttons_position
  end

  private

  def assert_below_carousel
    assert_selector '.compact-carousel'
    assert find('.section-actions', visible: true).evaluate_script('this.getBoundingClientRect().top >= document.querySelector(".card-collection").getBoundingClientRect().bottom')
  end

  def assert_form_below(alignment)
    form = find('.flexible-section__form')
    assert form.evaluate_script('this.getBoundingClientRect().top >= document.querySelector(".flexible-section__layout").getBoundingClientRect().bottom')
    assert_equal({ 'left' => 'start', 'center' => 'center', 'right' => 'end' }[alignment], form.evaluate_script('getComputedStyle(this).justifySelf'))
    offset = form.evaluate_script('this.getBoundingClientRect().left - this.parentElement.getBoundingClientRect().left')
    assert_operator offset, :>, 200 if alignment == 'right'
    assert_in_delta 0, offset, 1 if alignment == 'left'
  end

  def tint_metrics
    find('.compact-card', match: :first).evaluate_script(<<~JS)
      (() => {
        const overlay = getComputedStyle(this.querySelector('.compact-card__media'), '::after');
        return [overlay.backgroundColor, overlay.opacity, getComputedStyle(this.querySelector('.compact-card__title')).color];
      })()
    JS
  end
end
