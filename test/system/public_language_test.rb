require "application_system_test_case"

Selenium::WebDriver.logger.level = :warn

class PublicLanguageTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup do
    page.current_window.resize_to(1400, 1000)
    @tenant = Tenant.create!(name: "Idioma", slug: "idioma-browser", primary: true)
    @tenant.create_site_setting!(professional_name: "Idioma")
    @home = @tenant.pages.create!(name: "Home", slug: "home", published: true, show_in_nav: true)
    @article = @tenant.pages.create!(name: "Artigo", slug: "artigo", nav_label: "Artigo", nav_label_en: "Article", published: true, show_in_nav: true)
    [@home, @article].each do |record|
      record.sections.create!(section_type: "text", publication_state: "published", title: "Bem-vindo", title_en: "Welcome")
    end
    @forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection
  end

  test "desktop and footer change language on the same address and preserve it on navigation and refresh" do
    visit root_path
    within('.site-navbar__languages') { click_button "EN" }
    assert_selector 'html[lang="en"]'
    assert_current_path root_path
    assert_text "Welcome"
    page.refresh
    assert_selector 'html[lang="en"]'
    within('.site-navbar__navigation') { click_link "Article" }
    assert_current_path public_page_path(slug: @article.slug)
    assert_selector 'html[lang="en"]'
    within('.site-footer__languages') { click_button "PT" }
    assert_selector 'html[lang="pt-BR"]'
    assert_current_path public_page_path(slug: @article.slug)
    assert_text "Bem-vindo"
    page.refresh
    assert_selector 'html[lang="pt-BR"]'
    assert_no_selector 'a[href*="locale="]'
  end

  test "mobile menu retains the page and language without query parameters" do
    page.current_window.resize_to(390, 844)
    visit public_page_path(slug: @article.slug)
    find('.site-navbar__menu-button').click
    within('.site-navbar__mobile-languages') { click_button "EN" }
    assert_current_path public_page_path(slug: @article.slug)
    assert_selector 'html[lang="en"]'
    page.refresh
    assert_selector 'html[lang="en"]'
    assert_text "Welcome"
    find('.site-navbar__menu-button').click
    within('.site-navbar__mobile-languages') { click_button "PT" }
    assert_current_path public_page_path(slug: @article.slug)
    assert_selector 'html[lang="pt-BR"]'
  end
end
