require "application_system_test_case"
require "vips"
require "base64"

Selenium::WebDriver.logger.level = :warn

class VideoMediaSystemTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1440, 1100]

  setup do
    @tenant = Tenant.create!(name: "Vídeos", slug: "video-browser", primary: true)
    @tenant.create_site_setting!(professional_name: "Vídeos")
    @user = @tenant.users.create!(admin: true, email: "video-browser@example.test", password: "Video-browser-password-123!")
    @content_page = @tenant.pages.create!(name: "Mídias", slug: "midias")
    @section = @content_page.sections.create!(section_type: "cards", title: "Mídias", body: "Conteúdo", cards_wrap: false, cards_autoplay: false)
    login_as @user
  end
  teardown do
    Warden.test_reset!
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    @video_file&.close!
  end

  test "youtube preview follows input and card remains bounded with a working accessible player" do
    card = @section.section_items.create!(title: "Vídeo no card")
    visit edit_admin_page_section_section_item_path(@content_page, @section, card)
    select "Vídeo do YouTube", from: "Tipo de mídia"
    fill_in "Link do YouTube", with: "https://youtu.be/M7lc1UVf-VE"
    assert_selector '.compact-card .cms-video img[src*="M7lc1UVf-VE"]'
    card_box = find('.compact-card')
    assert_in_delta 440, card_box.evaluate_script('this.getBoundingClientRect().height'), 1
    save_screenshot(Rails.root.join('output/playwright/video-card-editor.png'))
    card_box.find('.cms-video__play').click
    assert_selector 'dialog[open] iframe[src^="https://www.youtube-nocookie.com/embed/M7lc1UVf-VE"]'
    find(".cms-video-dialog__close").click
    assert_no_selector 'dialog[open]'
    click_button "Salvar card"
    assert_text "Conteúdo atualizado"
    assert_equal 'youtube', card.reload.video_value('image', 'source')
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    find('.cms-video__play').click
    assert_selector 'dialog[open] iframe[referrerpolicy="strict-origin-when-cross-origin"]'
    page.send_keys(:escape)
    assert_no_selector 'dialog[open]'
  end

  test "local WebM preview plays before saving and persists with individual screen framing" do
    card = @section.section_items.create!(title: "Vídeo local")
    visit edit_admin_page_section_section_item_path(@content_page, @section, card)
    # Record a real, tiny WebM in Chromium; no external media, network or codec tools.
    encoded = page.evaluate_async_script(<<~JS)
      const done = arguments[0], canvas = document.createElement('canvas');
      canvas.width = 64; canvas.height = 48;
      const ctx = canvas.getContext('2d'), stream = canvas.captureStream(5);
      const recorder = new MediaRecorder(stream, {mimeType: 'video/webm'}), chunks = [];
      recorder.ondataavailable = e => chunks.push(e.data);
      recorder.onstop = () => { stream.getTracks().forEach(track => track.stop()); const reader = new FileReader(); reader.onload = () => done(reader.result.split(',')[1]); reader.readAsDataURL(new Blob(chunks, {type:'video/webm'})); };
      recorder.start(); ctx.fillStyle = '#458569'; ctx.fillRect(0, 0, 64, 48);
      setTimeout(() => { ctx.fillStyle = '#376950'; ctx.fillRect(8, 8, 32, 24); }, 150);
      setTimeout(() => recorder.stop(), 400);
    JS
    @video_file = Tempfile.new(['cms-video', '.webm'])
    @video_file.binmode; @video_file.write(Base64.decode64(encoded)); @video_file.flush
    select "Vídeo do computador", from: "Tipo de mídia"
    attach_file "Arquivo de vídeo (MP4 ou WebM)", @video_file.path
    assert_selector '.compact-card .cms-video video[src^="blob:"]'
    find('.cms-video__play').click
    assert_selector 'dialog[open] video' do |video|
      video.evaluate_script('this.readyState >= 2 && this.videoWidth === 64')
    end
    find(".cms-video-dialog__close").click
    find('summary', text: 'Enquadramento por tela').click
    fill_in 'Escala · Desktop', with: '1.5'
    within('.media-input__framing') { click_button 'Tablet' }
    fill_in 'Escala · Tablet', with: '0.75'
    within('.media-input__framing') { click_button 'Mobile' }
    fill_in 'Escala · Mobile', with: '0.4'
    assert_selector '.cms-video[data-preview-device="mobile"][style*="--video-mobile-zoom: 0.4"]'
    click_button 'Salvar card'
    assert_text 'Conteúdo atualizado'
    assert card.reload.video.attached?
    assert_equal 'video/webm', card.video.blob.content_type
    assert_equal '1.5', card.video_value('image', 'zoom')
    assert_equal '0.75', card.video_value('image', 'zoom', 'tablet')
    assert_equal '0.4', card.video_value('image', 'zoom', 'mobile')
  end

  test "card organization saves separately and changes on the public page at each breakpoint" do
    5.times { |n| @section.section_items.create!(title: "Card #{n}") }
    visit edit_admin_page_section_path(@content_page, @section)
    find('[data-tab="items"]').click
    within('.cards-settings') do
      click_button 'Tablet'
      click_button 'Vertical'
      select 'Esquerda', from: 'Alinhamento · Tablet'
      click_button 'Mobile'
      click_button 'Horizontal'
      select 'Quebrar em novas linhas', from: 'Comportamento · Mobile'
      select '2 cards', from: 'Cards por linha · Mobile'
      assert_selector '.cards-layout-preview.is-horizontal:not(.is-carousel)'
      click_button 'Desktop'
      assert_selector '.cards-layout-choice.is-selected[data-orientation="horizontal"]'
      assert_selector '.cards-layout-preview.is-carousel'
    end
    click_button 'Salvar alterações'
    assert_text 'Rascunho salvo'
    assert_equal 'vertical', @section.reload.visual_value('cards_orientation', 'tablet')
    assert @section.cards_carousel?
    assert_not @section.cards_carousel?('mobile')
    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    assert_selector '.card-collection[data-cards-mode="carousel"] .compact-carousel.is-overflowing'
    resize_to(850)
    assert_selector '.card-collection[data-cards-mode="vertical"]'
    assert_no_selector '.compact-carousel__arrow'
    widths = all('.compact-card').map { |card| card.evaluate_script('this.getBoundingClientRect().width') }
    assert widths.all? { |width| width <= 361 }
    resize_to(390)
    assert_selector '.card-collection[data-cards-mode="grid"]'
    assert_no_selector '.compact-carousel__arrow'
    first, second = all('.compact-card')[0,2]
    assert_in_delta first.evaluate_script('this.getBoundingClientRect().top'), second.evaluate_script('this.getBoundingClientRect().top'), 1
    assert_operator page.evaluate_script('document.documentElement.scrollWidth'), :<=, 391
    resize_to(1440)
    assert_selector '.compact-carousel.is-overflowing'
  end

  test "large cutout has a visibly larger frame than medium without horizontal overflow" do
    @section.update!(section_type: 'text', image_shape: 'cutout', media_size: 'medium')
    image = Vips::Image.black(400, 500).new_from_image([70, 110, 85, 255]).write_to_buffer('.png')
    @section.image.attach(io: StringIO.new(image), filename: 'portrait.png', content_type: 'image/png')
    logout
    %w[text_left text_right media_top].each do |layout|
      @section.update!(media_layout: layout, media_size: 'medium')
      PagePublicationService.new(page: @content_page).call
      visit public_page_path(slug: @content_page.slug)
      medium = find('.flexible-section__image-frame').evaluate_script('this.getBoundingClientRect().width')
      @section.update!(media_size: 'large')
      PagePublicationService.new(page: @content_page).call
      visit public_page_path(slug: @content_page.slug)
      large = find('.flexible-section__image-frame').evaluate_script('this.getBoundingClientRect().width')
      assert_operator large.to_f / medium, :>=, 1.35
      assert_operator page.evaluate_script('document.documentElement.scrollWidth'), :<=, 1441
    end
    resize_to(390)
    assert_operator page.evaluate_script('document.documentElement.scrollWidth'), :<=, 391
  end

  private
  def resize_to(width)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
  end
end
