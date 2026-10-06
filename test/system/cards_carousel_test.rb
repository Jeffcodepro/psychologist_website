require "application_system_test_case"
require "base64"

class CardsCarouselTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup do
    tenant = Tenant.create!(name: "Carrossel", slug: "carrossel", primary: true)
    tenant.create_site_setting!(professional_name: "Carrossel")
    @content_page = tenant.pages.create!(name: "Cards", slug: "cards")
    @section = @content_page.sections.create!(section_type: "cards", title: "Conteúdos", cards_wrap: false, cards_autoplay: true, cards_autoplay_seconds: 2)
    6.times { |i| @section.section_items.create!(title: "Card #{i + 1}", body: "Conteúdo para leitura.", position: i) }
    PagePublicationService.new(page: @content_page).call
  end

  teardown { Warden.test_reset! }

  test "hover does not delay the configured interval and mouse navigation keeps autoplay running" do
    open_carousel
    viewport.hover
    starts = observe_advances(6400)
    assert_operator starts.length, :>=, 3
    starts.each_cons(2) { |first, last| assert_in_delta 2000, last - first, 300 }

    find('.compact-carousel__arrow--next').click
    assert_not_nil carousel_timer
    # A click leaves focus on the arrow; it must still advance automatically.
    assert_operator observe_advances(2600).length, :>=, 1
  end

  test "keyboard focus pauses movement and the position control holds the chosen card without a pause button" do
    open_carousel
    assert_no_selector '.compact-carousel__playback', visible: :all
    page.execute_script("document.querySelector('.site-navbar a').focus()")
    15.times do
      page.driver.browser.action.send_keys(:tab).perform
      break if page.evaluate_script("document.activeElement.classList.contains('compact-carousel__arrow')")
    end
    assert page.evaluate_script("document.activeElement.matches('.compact-carousel__arrow:focus-visible')")
    assert_nil carousel_timer
    page.execute_script("document.querySelector('.site-navbar a').focus()")
    assert_not_nil carousel_timer
    find('.compact-carousel__range').send_keys(:end)
    assert_nil carousel_timer
    assert_operator viewport.evaluate_script('this.scrollLeft'), :>, 0
    # Let the direct range selection and its queued scroll event finish before
    # checking that the selected position stays still past the autoplay delay.
    positions = page.using_wait_time(10) do
      page.evaluate_async_script(<<~JS)
      const viewport = document.querySelector('[data-cards-carousel-target="viewport"]');
      const done = arguments[arguments.length - 1];
      requestAnimationFrame(() => requestAnimationFrame(() => {
        const start = viewport.scrollLeft;
        setTimeout(() => done([start, viewport.scrollLeft]), 2200);
      }));
      JS
    end
    assert_in_delta positions.first, positions.last, 1
  end

  test "live interval changes replace the old timer and disabling autoplay stops it" do
    open_carousel
    page.execute_script("document.querySelector('[data-controller=cards-carousel]').dataset.cardsCarouselDelayValue = '3000'")
    starts = observe_advances(6400)
    assert_equal 2, starts.length
    assert_in_delta 3000, starts.last - starts.first, 300
    page.execute_script("document.querySelector('[data-controller=cards-carousel]').dataset.cardsCarouselAutoplayValue = 'false'")
    assert_no_selector '.compact-carousel__playback'
    assert_nil carousel_timer
  end

  test "fitting cards and reduced motion do not start automatic movement" do
    @section.section_items.where.not(id: @section.section_items.first.id).destroy_all
    PagePublicationService.new(page: @content_page).call
    open_carousel(expect_controls: false)
    assert_no_selector '.compact-carousel__arrow'
    assert_no_selector '.compact-carousel__playback'
    assert_nil carousel_timer

    @section.section_items.create!(title: "Outro card")
    PagePublicationService.new(page: @content_page).call
    page.current_window.resize_to(390, 844)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [{ name: "prefers-reduced-motion", value: "reduce" }])
    open_carousel(expect_controls: false)
    assert_selector '.compact-carousel__arrow', count: 2
    assert_no_selector '.compact-carousel__playback'
    assert_nil carousel_timer
    find('.compact-carousel__arrow--next').click
    assert_operator viewport.evaluate_script("this.scrollLeft"), :>, 0
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
    page.current_window.resize_to(1400, 1000)
  end

  test "desktop and tablet keep compact cards and a position bar while mobile uses pagination" do
    @section.update!(cards_columns_desktop: 2, cards_columns_tablet: 2, cards_columns_mobile: 1, cards_autoplay: false)
    @section.section_items.order(:id).last(2).each(&:destroy!)
    PagePublicationService.new(page: @content_page).call
    [1280, 820].each do |width|
      page.current_window.resize_to(width, 1000)
      open_carousel(expect_controls: false)
      assert_no_selector '.compact-carousel__dot'
      assert_selector '.compact-carousel__position'
      find_all('.compact-card').each do |card|
        assert_operator card.evaluate_script('this.getBoundingClientRect().width'), :<=, 361
        assert_in_delta 440, card.evaluate_script('this.getBoundingClientRect().height'), 1
      end
      find('.compact-carousel__range').send_keys(:end)
      assert_operator viewport.evaluate_script('this.scrollLeft'), :>, 100
      assert_text(width == 1280 ? '2–4 / 4' : '3–4 / 4')
      capture_carousel(width.to_s)
    end
    page.current_window.resize_to(500, 844)
    assert_selector '.compact-carousel__dot', count: 4
    assert_no_selector '.compact-carousel__position'
    find('.compact-carousel__dot[data-page-index="3"]').click
    assert_selector '.compact-carousel__dot[aria-current="true"][data-page-index="3"]'
    capture_carousel('mobile')
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  test "navigation appears only when compact cards no longer fit the available space" do
    @section.section_items.order(:id).last(3).each(&:destroy!)
    PagePublicationService.new(page: @content_page).call
    page.current_window.resize_to(1280, 1000)
    open_carousel(expect_controls: false)
    assert_no_selector '.compact-carousel.is-overflowing'
    assert_no_selector '.compact-carousel__arrow'
    assert_no_selector '.compact-carousel__position'
    assert_nil carousel_timer
    assert_equal 3, fully_visible_cards
    assert_in_delta 0, viewport.evaluate_script('this.scrollWidth - this.clientWidth'), 1
    assert_in_delta 0, find('.compact-carousel__stage').evaluate_script('parseFloat(getComputedStyle(this).paddingLeft)'), 0.1
    capture_carousel('desktop-three-fit')

    page.current_window.resize_to(820, 1000)
    assert_selector '.compact-carousel.is-overflowing'
    assert_selector '.compact-carousel__arrow', count: 2
    assert_equal 2, fully_visible_cards
    assert_not_nil carousel_timer
    capture_carousel('tablet-two-visible')

    page.current_window.resize_to(1280, 1000)
    assert_no_selector '.compact-carousel.is-overflowing'
    assert_no_selector '.compact-carousel__position'
    assert_nil carousel_timer
    assert_in_delta 0, viewport.evaluate_script('this.scrollLeft'), 1
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  test "fewer cards keep their compact width and alignment without navigation" do
    @section.section_items.order(:id).last(4).each(&:destroy!)
    PagePublicationService.new(page: @content_page).call
    [1280, 820].each do |width|
      page.current_window.resize_to(width, 1000)
      open_carousel(expect_controls: false)
      assert_no_selector '.compact-carousel__arrow'
      assert_no_selector '.compact-carousel__position'
      assert_nil carousel_timer
      find_all('.compact-card').each do |card|
        assert_operator card.evaluate_script('this.getBoundingClientRect().width'), :<=, 361
      end
      assert_equal 2, fully_visible_cards
      %w[left center right].each do |alignment|
        page.execute_script("document.querySelector('.card-collection').className = 'card-collection card-collection--horizontal card-collection--' + arguments[0]", alignment)
        spacing = viewport.evaluate_script(<<~JS)
          (() => {
            const bounds = this.getBoundingClientRect();
            const cards = this.querySelectorAll('.compact-card');
            return { left: cards[0].getBoundingClientRect().left - bounds.left,
              right: bounds.right - cards[cards.length - 1].getBoundingClientRect().right };
          })()
        JS
        if alignment == 'center'
          assert_in_delta spacing['left'], spacing['right'], 1
        else
          assert_in_delta 0, spacing.fetch(alignment), 1
        end
      end
    end
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  test "legacy one-column settings cannot expand carousel images in public or preview" do
    @section.update!(cards_columns_desktop: 1, cards_columns_tablet: 1, cards_autoplay: false)
    @section.section_items.last.destroy!
    image = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=')
    @section.section_items.each_with_index do |item, index|
      item.update!(image_shape: index.zero? ? 'square' : 'rounded')
      item.update!(body: nil) if index == 2
      item.update!(body: "Um texto maior para conferir o alinhamento entre cards com conteúdos diferentes. " * 3) if index.zero?
      item.image.attach(io: StringIO.new(image), filename: 'carousel.png', content_type: 'image/png') unless index == 4
    end
    PagePublicationService.new(page: @content_page).call
    user = @content_page.tenant.users.create!(admin: true, email: 'carousel-settings@example.test', password: 'Carousel-test-password-123!')
    [:public, :preview].each do |mode|
      login_as user if mode == :preview
      [[1280, 3], [820, 2], [500, 1]].each do |width, quantity|
        page.current_window.resize_to(width, 1000)
        visit(mode == :preview ? admin_page_preview_frame_path(@content_page) : public_page_path(slug: @content_page.slug))
        assert_selector '.compact-carousel.is-overflowing'
        assert_equal quantity, fully_visible_cards
        metrics = find_all('.compact-card').map do |card|
          dimensions = card.evaluate_script('({width: this.getBoundingClientRect().width, height: this.getBoundingClientRect().height})')
          assert_operator dimensions['width'], :<=, 361 if width > 600
          assert_in_delta 440, dimensions['height'], 1
          assert card.evaluate_script('this.scrollHeight <= this.clientHeight + 1'), 'Content must fit the card'
          dimensions['width']
        end
        assert_in_delta metrics.min, metrics.max, 1
        assert_equal_card_heights
        capture_carousel("#{mode}-images-#{width}")
      end
    end
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  test "wrapping into new rows never enables carousel controls" do
    @section.update!(cards_wrap: true)
    PagePublicationService.new(page: @content_page).call
    visit public_page_path(slug: @content_page.slug)
    assert_selector '.card-collection__grid .compact-card', count: 6
    assert_no_selector '.compact-carousel', visible: :all
  end

  test "wrapped rows keep the same card height with and without images or body text" do
    @section.update!(cards_wrap: true, cards_columns_desktop: 3, cards_columns_tablet: 2)
    items = @section.section_items.order(:id).to_a
    image = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=')
    items.first.update!(image_shape: 'square', body: 'Texto mais longo para conferir os espaços e a leitura dentro de cada card. ' * 3)
    items.first.image.attach(io: StringIO.new(image), filename: 'equal-cards.png', content_type: 'image/png')
    items.last.update!(body: nil)
    PagePublicationService.new(page: @content_page).call
    [1280, 820, 500].each do |width|
      page.current_window.resize_to(width, 1000)
      visit public_page_path(slug: @content_page.slug)
      assert_selector '.card-collection__grid .compact-card', count: 6
      assert_equal_card_heights
      find_all('.compact-card').each do |card|
        assert card.evaluate_script('this.scrollHeight <= this.clientHeight + 1'), 'Content must fit the card'
      end
    end
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  private

  def assert_equal_card_heights
    heights = find_all('.compact-card').map { |card| card.evaluate_script('this.getBoundingClientRect().height') }
    heights.each { |height| assert_in_delta 440, height, 1, 'Every card must keep the fixed height' }
  end

  def fully_visible_cards
    viewport.evaluate_script(<<~JS)
      (() => {
        const bounds = this.getBoundingClientRect();
        return [...this.querySelectorAll('.compact-card')].filter(card => {
          const rect = card.getBoundingClientRect();
          return rect.left >= bounds.left - 1 && rect.right <= bounds.right + 1;
        }).length;
      })()
    JS
  end

  def capture_carousel(device)
    return unless ENV['CMS_VISUAL_QA'] == '1'
    FileUtils.mkdir_p(Rails.root.join('tmp/screenshots/refinements'))
    save_screenshot(Rails.root.join("tmp/screenshots/refinements/carousel-#{device}.png"))
  end

  def open_carousel(expect_controls: true)
    visit public_page_path(slug: @content_page.slug)
    assert_selector '.compact-carousel'
    assert_selector '.compact-carousel__position' if expect_controls
  end

  def viewport
    find('[data-cards-carousel-target="viewport"]')
  end

  def carousel_timer
    page.evaluate_script("window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller=cards-carousel]'), 'cards-carousel').timer")
  end

  def observe_advances(duration)
    page.using_wait_time(10) do
      page.evaluate_async_script(<<~JS, duration)
        const viewport = document.querySelector('[data-cards-carousel-target="viewport"]');
        const starts = [];
        let lastScroll = null;
        const listener = () => {
          const now = performance.now();
          if (lastScroll === null || now - lastScroll > 250) starts.push(now);
          lastScroll = now;
        };
        viewport.addEventListener('scroll', listener);
        const done = arguments[arguments.length - 1];
        setTimeout(() => { viewport.removeEventListener('scroll', listener); done(starts); }, arguments[0]);
      JS
    end
  end
end
