require "application_system_test_case"
require "base64"

class SpacingControlsTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup do
    @tenant = Tenant.create!(name: 'Espaços', slug: 'spacing', primary: true)
    @tenant.create_site_setting!(professional_name: 'Espaços')
    TenantProvisioner.ensure_contact_page!(@tenant)
    @user = @tenant.users.create!(admin: true, email: 'spacing-browser@example.test', password: 'Spacing-local-tests-123!')
    @content_page = @tenant.pages.create!(name: 'Página', slug: 'pagina')
    @section = @content_page.sections.create!(section_type: 'text_image', title: 'Título de exemplo', body: "Primeiro parágrafo.\n\nSegundo parágrafo.",
      media_layout: 'text_left', title_body_gap: 63, image_text_gap: 48, buttons_gap: 31, paragraph_spacing: 27, cards_content_gap: 42,
      action_buttons: [{ label: 'Converse comigo', action: 'contact', style: 'primary' }],
      responsive_settings: { mobile: { media_layout: 'media_between', image_text_gap: 13, title_body_gap: 5, buttons_gap: 17, cards_content_gap: 20 } })
    image = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=')
    @section.image.attach(io: StringIO.new(image), filename: 'spacing.png', content_type: 'image/png')
    @section.section_items.create!(title: 'Card de exemplo', body: 'Descrição do card.')
  end

  teardown do
    Warden.test_reset!
    page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
  end

  def publish_and_visit
    PagePublicationService.new(page: @content_page).call
    visit public_page_path(slug: @content_page.slug)
  end

  def distance(first, second)
    page.evaluate_script("document.querySelector('#{second}').getBoundingClientRect().top - document.querySelector('#{first}').getBoundingClientRect().bottom")
  end

  test 'public gaps are independent for text image buttons paragraphs and cards on each device' do
    publish_and_visit
    assert_in_delta 63, distance('.preview-movable--title', '.preview-movable--body'), 1
    assert_in_delta 31, distance('.preview-movable--body', '.section-actions--inline'), 1
    assert_in_delta 27, distance('.section-body p:first-child', '.section-body p:last-child'), 1
    assert_in_delta 42, distance('.flexible-section__layout', '.card-collection'), 1
    assert_equal '48px', find('.flexible-section__layout').evaluate_script('getComputedStyle(this).columnGap')
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 390, height: 1000, deviceScaleFactor: 1, mobile: false)
    assert_in_delta 13, distance('.preview-movable--title', '.flexible-section__media'), 1
    assert_in_delta 13, distance('.flexible-section__media', '.preview-movable--body'), 1
    assert_in_delta 17, distance('.preview-movable--body', '.section-actions--inline'), 1
    assert_in_delta 20, distance('.flexible-section__layout', '.card-collection'), 1
    save_screenshot(Rails.root.join('output/playwright/spacing-mobile.png'))
  end

  test 'zero gaps reversed text and buttons above or below carousel follow visual order' do
    @section.update!(title_body_gap: 0, text_order: 'body_first', buttons_position: 'before_cards', buttons_gap: 25)
    publish_and_visit
    assert_in_delta 0, distance('.preview-movable--body', '.preview-movable--title'), 1
    assert_in_delta 25, distance('.flexible-section__layout', '.section-actions--collection'), 1
    assert_in_delta 25, distance('.section-actions--collection', '.card-collection'), 1
    @section.update!(buttons_position: 'after_cards', cards_placement: 'before')
    publish_and_visit
    assert_in_delta 25, distance('.card-collection', '.section-actions--collection'), 1
    assert_in_delta 25, distance('.section-actions--collection', '.flexible-section__layout'), 1
    @section.update!(title: '', buttons_position: 'after_text')
    publish_and_visit
    assert_equal '0px', find('.preview-movable--body').evaluate_script('getComputedStyle(this).marginTop')
  end

  test 'editor controls save per device and the preview uses the published spacing rules' do
    login_as @user
    visit edit_admin_page_section_path(@content_page, @section)
    find('[data-tab="appearance"]').click
    fill_in "layout_#{@section.id}_desktop_title_body_gap", with: '44'
    fill_in "layout_#{@section.id}_desktop_image_text_gap", with: '60'
    click_button 'Salvar alterações'
    assert_text 'Rascunho salvo.'
    assert_equal '44', @section.reload.title_body_gap
    visit admin_page_preview_frame_path(@content_page)
    assert_in_delta 44, distance('.preview-movable--title', '.preview-movable--body'), 1
    assert_equal '60px', find('.flexible-section__layout').evaluate_script('getComputedStyle(this).columnGap')
  end
  test 'card spacing updates immediately and publication keeps the same fixed box' do
    card = @section.section_items.first
    card.image.attach(@section.image.blob)
    card.update!(body: 'Descrição do card. ' * 40)
    login_as @user
    visit edit_admin_page_section_section_item_path(@content_page, @section, card)
    fill_in 'section_item_desktop_text_padding', with: '8'
    fill_in 'section_item_desktop_title_body_gap', with: '26'
    fill_in 'section_item_desktop_image_text_gap', with: '34'
    fill_in 'section_item_desktop_button_gap', with: '20'
    assert_equal ['440px', '34px', '8px', '26px', '20px'], card_spacing_metrics
    click_button 'Salvar card'
    assert_text 'Conteúdo atualizado com sucesso.'
    assert_equal '34', card.reload.card_value('image_text_gap').to_s
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    assert_equal ['440px', '34px', '8px', '26px', '20px'], card_spacing_metrics
    assert_selector '.compact-card__read-more:not([hidden])'
    card.update!(title: 'Um título bem longo para ocupar duas linhas no card', card_settings: { desktop: {
      image_layout: 'between_text', text_padding: 40, title_body_gap: 40, image_text_gap: 40, button_gap: 40
    } })
    publish_and_visit
    assert_equal '440px', card_spacing_metrics.first
    assert find('.compact-card').evaluate_script('this.querySelector(".compact-card__actions").getBoundingClientRect().bottom <= this.getBoundingClientRect().bottom')
  end

  def card_spacing_metrics
    page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector('.compact-card');
        const style = part => getComputedStyle(card.querySelector(part));
        return [getComputedStyle(card).height, style('.compact-card__heading').paddingTop,
          style('.compact-card__heading').paddingLeft, style('.compact-card__body').paddingTop,
          style('.compact-card__actions').paddingTop];
      })()
    JS
  end

end
