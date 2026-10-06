require "application_system_test_case"
require "base64"

class CompositionTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup do
    @tenant = Tenant.create!(name: "Composição", slug: "composicao", primary: true)
    @tenant.create_site_setting!(professional_name: "Composição")
    @user = @tenant.users.create!(admin: true, email: "layout@example.test", password: "Layout-test-password-123!")
    @content_page = @tenant.pages.create!(name: "Composição", slug: "composicao", show_in_nav: true)
    @section = @content_page.sections.create!(section_type: "hero", title: "Título da seção", title_en: "Section title", body: "Parágrafo de apresentação.", anchor: "intro",
      action_buttons: [{ label: "Conhecer", action: "anchor", value: "intro", style: "primary" }])
    @cards = @content_page.sections.create!(section_type: "cards", title: "Áreas de atuação", position: 2, cards_wrap: false, cards_autoplay: false)
    3.times do |i|
      item = @cards.section_items.create!(title: "Desenvolvimento Humano #{i}", body: "Experiências de aprendizagem, treinamentos e palestras para pessoas, equipes e organizações que desejam fortalecer relações, comunicação e desenvolvimento profissional.", linked_page: @content_page, position: i)
      attach_image(item)
    end
    attach_image(@section)
    PagePublicationService.new(page: @content_page).call
  end

  teardown do
    Warden.test_reset!
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.current_window.resize_to(1400, 1000)
  end

  test "cards constrain images and text to the same fixed box on all screens" do
    [390, 820, 1400].each do |width|
      resize_viewport(width)
      visit public_page_path(slug: @content_page.slug)
      assert_selector '.compact-card__image'
      find('.compact-card', match: :first).execute_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
      metrics = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('.compact-card')).map(card => {
          const body = card.querySelector('.compact-card__body');
          const button = card.querySelector('.compact-card__link');
          const frame = card.querySelector('.compact-card__image-frame').getBoundingClientRect();
          return { height: card.getBoundingClientRect().height, mediaHeight: frame.height, fits: body.scrollHeight <= body.clientHeight + 1,
            separated: body.getBoundingClientRect().bottom <= button.getBoundingClientRect().top,
            visible: button.getBoundingClientRect().bottom <= card.getBoundingClientRect().bottom };
        });
      JS
      metrics.each do |metric|
        assert_in_delta 440, metric['height'], 1
        assert_in_delta 190, metric['mediaHeight'], 1
        assert metric['fits'], 'The visible excerpt must fit'
        assert metric['separated'], 'Button must not overlap text'
        assert metric['visible'], 'Button must stay inside the card'
      end
      assert page.evaluate_script('document.documentElement.scrollWidth <= innerWidth + 1')
      capture("cards-#{width}")
    end
  end

  test "mobile image can sit between texts or above buttons independently of desktop" do
    login_as @user
    resize_viewport(390)
    visit admin_page_preview_frame_path(@content_page)
    frame = find("[data-section-frame-id='#{@section.id}']")
    frame.find('[data-move-field="image"]').click
    frame.find('[data-position="between"]').click
    assert_selector '[data-visual-drag-target="status"]', text: 'Posição salva'
    assert_equal 'media_between', @section.reload.visual_value('media_layout', 'mobile')
    assert_equal 'text_left', @section.media_layout
    assert_between_image(frame, '.preview-movable--title', '.preview-movable--body')
    frame.find('[data-move-field="image"]').click
    frame.find('[data-position="before_buttons"]').click
    assert_selector "[data-section-frame-id='#{@section.id}'][data-layout-mobile='media_before_buttons']"
    assert_between_image(frame, '.preview-movable--body', '.section-actions')
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    frame = find('.section-frame', match: :first)
    assert_between_image(frame, '.preview-movable--body', '.section-actions')
  end

  test "all card layouts and button positions retain readable content" do
    resize_viewport(390)
    card = @cards.section_items.first
    CardPresentation::OPTIONS['image_layout'].each do |_label, layout|
      card.update!(card_settings: { desktop: { image_layout: layout, button_alignment: 'right', button_position: 'bottom' } })
      PagePublicationService.new(page: @content_page).call
      visit public_page_path(slug: @content_page.slug)
      assert_selector ".compact-card[data-card-layout-mobile='#{layout}']"
      element = find('.compact-card', match: :first)
      element.execute_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
      assert element.evaluate_script('this.scrollHeight <= this.clientHeight + 1'), "#{layout} must fit"
      assert_equal 'flex-end', element.find('.compact-card__actions').evaluate_script('getComputedStyle(this).justifyContent')
      if layout == 'background'
        assert_equal 'rgb(255, 255, 255)', element.find('.compact-card__title').evaluate_script('getComputedStyle(this).color')
      end
    end
  end

  test "image and banner backgrounds keep the text and actions above both layers" do
    @section.banner.attach(@section.image.blob)
    @section.update!(banner_layout: "background", media_layout: "media_background", title_color: "#ffffff", body_color: "#ffffff", banner_overlay: 65)
    PagePublicationService.new(page: @content_page).call
    resize_viewport(390)
    visit public_page_path(slug: @content_page.slug)
    frame = find('.section-frame', match: :first)
    assert_equal 'absolute', frame.find('.flexible-section__media').evaluate_script('getComputedStyle(this).position')
    assert_equal 'absolute', frame.find('.section-frame__banner').evaluate_script('getComputedStyle(this).position')
    button = frame.find('.site-action')
    button.execute_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
    assert button.evaluate_script("(() => { const r = this.getBoundingClientRect(); return this.contains(document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2)) })()")
    capture('section-background-mobile')
  end

  test "card button has all alignments and three positions without covering the summary" do
    login_as @user
    card = @cards.section_items.first
    visit edit_admin_page_section_section_item_path(@content_page, @cards, card)
    select 'Abaixo', from: 'section_item_desktop_image_layout'
    select 'Direita', from: 'section_item_desktop_button_alignment'
    select 'Topo', from: 'section_item_desktop_button_position'
    click_button 'Salvar card'
    assert_text 'Conteúdo atualizado com sucesso.'
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    element = find('.compact-card', match: :first)
    assert_equal 'bottom', element['data-card-layout-desktop']
    assert_equal 'right', element['data-card-align-desktop']
    %w[top center bottom].each do |position|
      %w[left center right].each do |alignment|
        element.execute_script("this.dataset.cardButtonDesktop = arguments[0]; this.dataset.cardAlignDesktop = arguments[1]", position, alignment)
        expected = { 'left' => 'flex-start', 'center' => 'center', 'right' => 'flex-end' }.fetch(alignment)
        assert_equal expected, element.find('.compact-card__actions').evaluate_script('getComputedStyle(this).justifyContent')
        assert element.evaluate_script(<<~JS)
          (() => {
            const action = this.querySelector('.compact-card__actions').getBoundingClientRect();
            const body = this.querySelector('.compact-card__body').getBoundingClientRect();
            return action.bottom <= body.top + 1 || action.top >= body.bottom - 1;
          })()
        JS
      end
    end
  end

  test "SEO examples only fill fields on request and can be edited before saving" do
    login_as @user
    @content_page.update!(seo_title: 'Título que deve permanecer')
    visit edit_admin_page_path(@content_page)
    assert_field 'Título SEO', with: 'Título que deve permanecer'
    within('.seo-editor', match: :first) do
      click_button 'Usar modelo de título'
      assert_field 'Título SEO', with: 'Composição | Composição'
      fill_in 'Descrição SEO', with: 'Descrição escrita pela profissional.'
      assert_selector '[data-seo-editor-target="previewDescription"]', text: 'Descrição escrita pela profissional.'
      capture('seo-editor')
    end
    assert_equal 'Título que deve permanecer', @content_page.reload.seo_title
  end

  test "admin language stays in English after navigating to another page without query parameters" do
    login_as @user
    visit admin_page_preview_path(@content_page)
    find('[data-admin-page-preview-target="languageButton"][data-locale="en"]').click
    within_frame(find('iframe')) { assert_selector 'html[lang="en"]', visible: :all; assert_text 'Section title' }
    assert_current_path admin_page_preview_path(@content_page)
    visit edit_admin_page_section_path(@content_page, @section)
    assert_no_selector 'a[href*="locale="]'
    visit admin_page_preview_path(@content_page)
    within_frame(find('iframe')) { assert_text 'Section title'; assert_no_selector 'a[href*="locale="]' }
  end

  private

  def capture(name)
    return unless ENV['CMS_VISUAL_QA'] == '1'
    FileUtils.mkdir_p(Rails.root.join('tmp/screenshots/composition'))
    save_screenshot(Rails.root.join("tmp/screenshots/composition/#{name}.png"))
  end

  def resize_viewport(width)
    page.current_window.resize_to([width, 600].max, 1000)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
  end

  def attach_image(record)
    png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=')
    record.image.attach(io: StringIO.new(png), filename: 'composition.png', content_type: 'image/png')
  end

  def assert_between_image(frame, above, below)
    assert frame.evaluate_script(<<~JS, above, below)
      (() => {
        const image = this.querySelector('.flexible-section__media').getBoundingClientRect();
        return this.querySelector(arguments[0]).getBoundingClientRect().bottom <= image.top + 1 &&
          image.bottom <= this.querySelector(arguments[1]).getBoundingClientRect().top + 1;
      })()
    JS
  end
end
