require "application_system_test_case"

class CardsCarouselTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup do
    tenant = Tenant.create!(name: "Carrossel", slug: "carrossel", primary: true)
    tenant.create_site_setting!(professional_name: "Carrossel")
    @content_page = tenant.pages.create!(name: "Cards", slug: "cards")
    @section = @content_page.sections.create!(section_type: "cards", title: "Conteúdos", cards_wrap: false, cards_autoplay: true, cards_autoplay_seconds: 2)
    6.times { |i| @section.section_items.create!(title: "Card #{i + 1}", body: "Conteúdo para leitura.", position: i) }
    PagePublicationService.new(page: @content_page).call
  end

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

  test "explicit pause and resume work and keyboard focus resumes after leaving the carousel" do
    open_carousel
    find('.compact-carousel__playback').click
    assert_selector '.compact-carousel__playback[aria-pressed="true"]', text: "Retomar"
    assert_nil carousel_timer
    assert_empty observe_advances(2200)
    find('.compact-carousel__playback').click
    assert_not_nil carousel_timer
    assert_operator observe_advances(2500).length, :>=, 1

    # Tab into the previous arrow from the preceding navigation item.
    page.execute_script("document.querySelector('.site-navbar a').focus()")
    15.times do
      page.driver.browser.action.send_keys(:tab).perform
      break if page.evaluate_script("document.activeElement.classList.contains('compact-carousel__arrow')")
    end
    assert page.evaluate_script("document.activeElement.matches('.compact-carousel__arrow:focus-visible')")
    assert_nil carousel_timer
    5.times do
      page.driver.browser.action.send_keys(:tab).perform
      break if page.evaluate_script("document.activeElement.classList.contains('compact-carousel__playback')")
    end
    assert page.evaluate_script("document.activeElement.classList.contains('compact-carousel__playback')")
    page.driver.browser.action.send_keys(:space).perform
    assert_nil carousel_timer
    page.driver.browser.action.send_keys(:space).perform
    assert_not_nil carousel_timer
    page.execute_script("document.querySelector('.site-navbar a').focus()")
    assert_not_nil carousel_timer
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

  private

  def open_carousel(expect_controls: true)
    visit public_page_path(slug: @content_page.slug)
    assert_selector '.compact-carousel'
    assert_selector '.compact-carousel__playback' if expect_controls
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
