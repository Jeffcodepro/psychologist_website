require "test_helper"

class LanguagePreferencesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Idioma", slug: "idioma-teste", primary: true)
    @tenant.create_site_setting!(professional_name: "Idioma")
    @home = @tenant.pages.create!(name: "Home", slug: "home", published: true, show_in_nav: true)
    @article = @tenant.pages.create!(name: "Artigo", slug: "artigo", published: true, show_in_nav: true)
    [@home, @article].each do |page|
      page.sections.create!(section_type: "text", publication_state: "published", title: "Bem-vindo", title_en: "Welcome")
    end
    @contact = TenantProvisioner.ensure_contact_page!(@tenant)
  end

  test "choice persists on clean public URLs and stays private to the visitor" do
    get root_path
    assert_select 'html[lang="pt-BR"]'
    assert_select 'a[href*="locale="]', count: 0
    assert_select 'form.site-language-form[action="/idioma"]', count: 6

    post language_preference_path, params: { language: "en", return_to: "/artigo?utm_source=menu" }
    assert_response :see_other
    assert_redirected_to "/artigo?utm_source=menu"
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_includes response.headers["Set-Cookie"].to_s.downcase, "httponly"
    assert_includes response.headers["Set-Cookie"].to_s.downcase, "samesite=lax"
    assert_not_equal "en", cookies[:site_locale]
    follow_redirect!
    assert_select 'html[lang="en"]'
    assert_select 'h2', text: "Welcome"
    assert_includes response.headers["Cache-Control"], "private"
    assert_select 'a[href*="locale="]', count: 0
    assert_select 'form[action*="locale="]', count: 0
    get root_path
    assert_select 'html[lang="en"]'
    get contact_path
    assert_select 'html[lang="en"]'
    assert_select 'form.appointment-form[action="/contato"]'

    visitor = open_session
    visitor.get root_path
    visitor.assert_select 'html[lang="pt-BR"]'

    post language_preference_path, params: { language: "pt-BR", return_to: "/artigo" }
    follow_redirect!
    assert_select 'html[lang="pt-BR"]'
    assert_select 'h2', text: "Bem-vindo"
  end

  test "old language links clean the URL and preserve unrelated parameters" do
    get "/artigo?locale=en&utm_source=old"
    assert_response :see_other
    assert_redirected_to "/artigo?utm_source=old"
    assert_includes response.headers["Cache-Control"], "no-store"
    follow_redirect!
    assert_select 'html[lang="en"]'
    get "/contato?locale=pt-BR"
    assert_redirected_to "/contato"
    follow_redirect!
    assert_select 'html[lang="pt-BR"]'
    head "/artigo?locale=en"
    assert_response :see_other
    assert_redirected_to "/artigo"
  end

  test "invalid preferences never change the language or cause server errors" do
    post language_preference_path, params: { language: "en", return_to: "/" }
    ["fr", ["en"], { value: "en" }, ""].each do |language|
      post language_preference_path, params: { language: language, return_to: "/" }
      assert_response :unprocessable_entity
      get root_path
      assert_select 'html[lang="en"]'
    end
    ["locale=fr", "locale[]=en", "locale[other]=en"].each do |query|
      get "/artigo?#{query}"
      assert_redirected_to "/artigo"
      follow_redirect!
      assert_select 'html[lang="en"]'
    end
    cookies[:site_locale] = "tampered"
    get root_path
    assert_select 'html[lang="pt-BR"]'
  end

  test "return paths cannot redirect outside the site or into the CMS" do
    ["https://example.org/", "//example.org/", "/\\example.org/", "/admin", "/admin/access/invalid",
     "/s/outro/artigo", "/sitemap.xml", "/idioma/extra", "/artigo\nLocation:evil", "/%ZZ", { value: "/" }].each do |destination|
      post language_preference_path, params: { language: "en", return_to: destination }
      assert_response :see_other
      assert_redirected_to root_path
    end
    post language_preference_path, params: { language: "en", return_to: "/artigo?locale=pt-BR&search=one%20two#leitura" }
    assert_redirected_to "/artigo?search=one+two#leitura"
  end

  test "scoped tenant navigation and language forms retain their site" do
    path = public_page_path(site_slug: @tenant.slug, slug: @article.slug)
    endpoint = language_preference_path(site_slug: @tenant.slug)
    get path
    assert_select 'form.site-language-form[action=?]', endpoint, count: 6
    post endpoint, params: { language: "en", return_to: path }
    assert_redirected_to path
    follow_redirect!
    assert_select 'html[lang="en"]'
    assert_select 'a[href=?]', root_path(site_slug: @tenant.slug)
    assert_select 'a[href*="locale="]', count: 0
    post endpoint, params: { language: "pt-BR", return_to: "/artigo" }
    assert_redirected_to root_path(site_slug: @tenant.slug)
  end

  test "language changes require a valid CSRF token" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get root_path
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    post language_preference_path, params: { language: "en", return_to: "/" }
    assert_response :unprocessable_entity
    post language_preference_path, params: { language: "en", return_to: "/", authenticity_token: token }
    assert_response :see_other
    follow_redirect!
    assert_select 'html[lang="en"]'
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "the public language does not change the administrators preview preference" do
    post language_preference_path, params: { language: "en", return_to: "/" }
    user = @tenant.users.create!(admin: true, email: "language@example.test", password: "Language-test-password-123!")
    sign_in user
    get admin_page_preview_frame_path(@home)
    assert_select 'html[lang="pt-BR"]'
    assert_select 'form.site-language-form[action="/admin/idioma"][target="_top"]', count: 6
    assert_select 'a[href*="locale="]', count: 0
    post language_preference_path, params: { language: "pt-BR", return_to: "/" }
    assert_redirected_to admin_root_path
    sign_out user
    get root_path
    assert_select 'html[lang="en"]'
  end
end
