require "test_helper"

class Admin::LanguagePreferencesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @tenant = Tenant.create!(name: "Idioma", slug: "idioma", primary: true)
    @tenant.create_site_setting!(professional_name: "Idioma")
    @user = @tenant.users.create!(admin: true, email: "language-admin@example.test", password: "Language-test-password-123!")
    sign_in @user
    @page = @tenant.pages.create!(name: "Página", slug: "pagina", show_in_nav: true)
    @page.sections.create!(title: "Português", title_en: "English", section_type: "text")
  end

  test "legacy preview URL is cleaned and language persists in links and frames" do
    get admin_page_preview_path(@page, locale: :en, device: "mobile")
    assert_response :see_other
    assert_redirected_to admin_page_preview_path(@page, device: "mobile")
    follow_redirect!
    assert_select '[data-admin-page-preview-locale-value="en"]'
    assert_select 'iframe[src=?]', admin_page_preview_frame_path(@page)
    assert_select 'a[href*="locale="]', count: 0
    get admin_page_preview_frame_path(@page)
    assert_select 'html[lang="en"]'
    assert_select 'h2', text: "English"
    assert_select 'form[action*="locale="]', count: 0
    post admin_language_preference_path, params: { language: "pt-BR" }, as: :json
    assert_response :success
    get admin_page_preview_frame_path(@page)
    assert_select 'html[lang="pt-BR"]'
    assert_select 'h2', text: "Português"
    assert_includes response.headers['Cache-Control'], 'no-store'
  end

  test "invalid inputs and foreign redirects cannot change or leave the CMS" do
    post admin_language_preference_path, params: { language: "en" }, as: :json
    ["fr", ["pt-BR"], { locale: "pt-BR" }].each do |language|
      post admin_language_preference_path, params: { language: language }, as: :json
      assert_response :unprocessable_entity
    end
    get admin_page_preview_frame_path(@page)
    assert_select 'html[lang="en"]'
    post admin_language_preference_path, params: { language: "en", return_to: "//evil.test" }
    assert_redirected_to admin_root_path
    sign_out @user
    post admin_language_preference_path, params: { language: "en" }, as: :json
    assert_response :not_found
  end

  test "language preference requires CSRF" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get admin_page_preview_path(@page)
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')['content']
    post admin_language_preference_path, params: { language: "en" }, as: :json
    assert_response :unprocessable_entity
    post admin_language_preference_path, params: { language: "en", authenticity_token: token }, as: :json
    assert_response :success
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
