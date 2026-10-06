require "application_system_test_case"
require "base64"

class CardBoundsTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup do
    @tenant = Tenant.create!(name: "Prévia", slug: "previa", primary: true)
    @tenant.create_site_setting!(professional_name: "Prévia")
    @user = @tenant.users.create!(admin: true, email: "preview@example.test", password: "Card-preview-test-123!")
    @content_page = @tenant.pages.create!(name: "Conteúdos", slug: "conteudos")
    @section = @content_page.sections.create!(section_type: "cards", title: "Cards", cards_wrap: true, cards_columns_desktop: 1)
    @card = @section.section_items.create!(title: "Um título para o card", body: "Texto de exemplo.", image_shape: "rectangle")
    @image = Tempfile.new(["card-preview", ".png"])
    @image.binmode
    @image.write Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=")
    @image.flush
    @card.image.attach(io: File.open(@image.path), filename: "card.png", content_type: "image/png")
    login_as @user
  end

  teardown do
    Warden.test_reset!
    @image.close!
    page.current_window.resize_to(1400, 1000)
  end

  test "new card preview updates text and upload before saving without expanding the box" do
    visit new_admin_page_section_section_item_path(@content_page, @section, item_kind: "card")
    assert_selector '.card-editor-preview .compact-card'
    fill_in "section_item_title", with: 'Novo título <img src=x onerror=alert(1)>'
    fill_in "section_item_body", with: "Uma mensagem completa para leitura. " * 60
    assert_selector '.card-editor-preview .compact-card__title', text: 'Novo título <img'
    assert_no_selector '.compact-card__title img', visible: :all
    attach_file "section_item[image]", @image.path, make_visible: true
    assert_selector '[data-image-cropper-target="dimensions"]', text: "Original: 1 × 1 px"
    assert_selector '.card-editor-preview .compact-card--with-image'
    assert_fixed_box
    assert_selector '.compact-card__read-more:not([hidden])'
    click_button 'Ler mais'
    assert_selector 'dialog[open]', text: "Uma mensagem completa para leitura. " * 10
    find('dialog .card-reader-dialog__close').click
    assert_equal 1, @section.section_items.count, 'Live edits must not save records'
    assert_no_selector 'dialog[open]'
    page.save_screenshot(Rails.root.join('output/playwright/card-live-preview.png'))
  end

  test "live frame matches published crop and dimensions including side and background layouts" do
    %w[top left between_text before_button bottom background].each do |layout|
      visit edit_admin_page_section_section_item_path(@content_page, @section, @card)
      select CardPresentation::OPTIONS['image_layout'].find { |_, value| value == layout }.first, from: 'section_item_desktop_image_layout'
      set_range('zoom', 1.45)
      set_range('y', 75)
      assert_selector ".card-editor-preview [data-card-layout-desktop='#{layout}']"
      assert_fixed_box
      editor = frame_metrics
      click_button 'Salvar card'
      assert_text 'Conteúdo atualizado com sucesso.'
      PagePublicationService.new(page: @content_page).call
      logout
      visit public_page_path(slug: @content_page.slug)
      assert_selector '.compact-card__image'
      published = frame_metrics
      %w[width height cardHeight].each { |key| assert_in_delta editor[key], published[key], 1, "#{layout}: #{key}" }
      %w[position transform font].each { |key| assert_equal editor[key], published[key], "#{layout}: #{key}" }
      login_as @user
    end
  end

  test "public hover preserves the exact rotation and flips from the crop editor" do
    @card.update!(image_zoom: 1.5, media_adjustments: { image: { rotation: 25, flip_x: -1 } })
    visit edit_admin_page_section_section_item_path(@content_page, @section, @card)
    expected = frame_metrics['transform']
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    image = find('.compact-card__image')
    image.execute_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
    image.hover
    assert_equal expected, frame_metrics['transform']
    assert_fixed_box
  end

  test "background images can be dragged directly in the preview" do
    @card.update!(card_settings: { desktop: { image_layout: 'background' } })
    visit edit_admin_page_section_section_item_path(@content_page, @section, @card)
    assert_selector '[data-image-cropper-target="dimensions"]', text: "Original: 1 × 1 px"
    frame = find('[data-image-cropper-target="frame"]')
    frame.execute_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
    page.driver.browser.action.move_to(frame.native).click_and_hold.move_by(0, 18).release.perform
    assert_operator find('[data-image-cropper-target="yField"]', visible: :all).value.to_i, :<, 50
    assert_fixed_box
  end

  test "device and width simulation match saved composition and removing the image keeps height" do
    visit edit_admin_page_section_section_item_path(@content_page, @section, @card)
    find('.card-presentation summary', text: 'Mobile', exact_text: true).click
    select 'Entre título e texto', from: 'section_item_mobile_image_layout'
    assert_selector '.card-editor-preview[data-device="mobile"]'
    card = find('.card-editor-preview .compact-card')
    assert card.evaluate_script('this.querySelector(".compact-card__heading").getBoundingClientRect().bottom <= this.querySelector(".compact-card__media").getBoundingClientRect().top')
    within '.card-editor-preview__toolbar' do
      click_button 'Desktop'
    end
    assert card.evaluate_script('this.querySelector(".compact-card__media").getBoundingClientRect().bottom <= this.querySelector(".compact-card__heading").getBoundingClientRect().top')
    find('input[aria-label="Largura da prévia"]').execute_script("this.value = 280; this.dispatchEvent(new Event('input', {bubbles: true}))")
    assert_selector '[data-card-preview-target="size"]', text: '280 × 440 px'
    check 'Remover imagem ao salvar'
    assert_no_selector '.card-editor-preview .compact-card__media'
    assert_fixed_box
    uncheck 'Remover imagem ao salvar'
    assert_selector '.card-editor-preview .compact-card__media'
  end

  test "visually clipped short text gets a reader and full content remains available" do
    body = 'Um espaço de escuta e cuidado para compreender emoções, reconhecer padrões e desenvolver novas formas de lidar com experiências, relações e desafios da vida.'
    @card.update!(title: 'Um título com muitas palavras para ocupar duas linhas', body: body, card_settings: { desktop: { image_layout: 'left' } })
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    assert_selector '.compact-card__read-more:not([hidden])'
    assert_fixed_box
    click_button 'Ler mais'
    assert_selector 'dialog[open]', text: body
    find('dialog').send_keys(:escape)
    assert_no_selector 'dialog[open]'
    assert_fixed_box
  end

  test "article teaser editor previews new text and target section fonts without saving" do
    other = @content_page.sections.create!(section_type: 'cards', title: 'Reflexões', title_font_family: 'lora')
    article = @tenant.pages.create!(name: 'Artigo', slug: 'artigo', content_kind: 'article')
    article.sections.create!(section_type: 'text', body: 'Introdução do texto completo.')
    visit edit_admin_article_card_path(article)
    fill_in 'article_card_title', with: 'Título do artigo atualizado'
    fill_in 'article_card_body', with: 'Uma chamada nova.'
    assert_selector '.card-editor-preview .compact-card__title', text: 'Título do artigo atualizado'
    assert_selector '.card-editor-preview .compact-card__body', text: 'Uma chamada nova.'
    select 'Reflexões', from: 'card_section'
    assert_match(/Lora/, find('.compact-card__title').evaluate_script('getComputedStyle(this).fontFamily'))
    fill_in 'article_card_body', with: ''
    assert_selector '.compact-card__summary', text: 'Introdução do texto completo.'
    assert_fixed_box
    assert_equal 0, article.linking_cards.count
  end

  private

  def assert_fixed_box
    card = find('.compact-card', match: :first)
    assert_in_delta 440, card.evaluate_script('this.getBoundingClientRect().height'), 1
    assert_operator card.evaluate_script('this.getBoundingClientRect().width'), :<=, 360
    assert card.evaluate_script('this.scrollHeight <= this.clientHeight + 1'), 'No overflowing card content'
  end

  def set_range(target, value)
    find("[data-image-cropper-target='#{target}']", visible: :all).execute_script("this.value = arguments[0]; this.dispatchEvent(new Event('input', { bubbles: true }))", value)
  end

  def frame_metrics
    find('.compact-card').evaluate_script(<<~JS)
      (() => {
        const frame = this.querySelector('.compact-card__image-frame').getBoundingClientRect();
        const image = getComputedStyle(this.querySelector('img'));
        return { width: frame.width, height: frame.height, cardHeight: this.getBoundingClientRect().height,
          position: image.objectPosition, transform: image.transform, font: getComputedStyle(this.querySelector('.compact-card__title')).fontFamily };
      })()
    JS
  end
end
