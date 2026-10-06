require "test_helper"
require "minitest/mock"

class Admin::MediaOverlaysTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Mídia", slug: "overlay", primary: true)
    @tenant.create_site_setting!(professional_name: "Mídia")
    @admin = @tenant.users.create!(admin: true, email: "overlay-admin@example.test", password: "Overlay-tests-password-123!")
    @page = @tenant.pages.create!(name: "Mídia", slug: "midia")
    @section = @page.sections.create!(section_type: "hero", title: "Conheça meu trabalho", body: "Texto preservado", banner_overlay: 30, overlay_color: "#314f3e")
    sign_in @admin
  end

  test "legacy background overlay is preserved without tinting normal photographs and banner strips" do
    %w[top bottom].each do |layout|
      @section.banner_layout = layout
      assert_equal 0, @section.media_overlay_value("banner", "opacity")
    end
    @section.banner_layout = "background"
    assert_equal 30, @section.media_overlay_value("banner", "opacity")
    assert_equal "#314f3e", @section.media_overlay_value("banner", "color")
    assert_equal 0, @section.media_overlay_value("image", "opacity")
    @section.media_layout = "media_background"
    @section.responsive_settings = { mobile: { banner_overlay: 60, overlay_color: "#aabbcc" } }
    assert_equal 30, @section.media_overlay_value("image", "opacity")
    assert_equal 60, @section.media_overlay_value("image", "opacity", "mobile")
    assert_equal "#aabbcc", @section.media_overlay_value("image", "color", "mobile")
  end

  test "independent overlays accept zero and full intensity publish and inherit desktop" do
    patch admin_page_section_path(@page, @section), params: { section: {
      banner_overlay_color: "#c08020", banner_overlay_opacity: 100, image_overlay_color: "#204080", image_overlay_opacity: 0,
      responsive_settings: { mobile: { image_overlay_opacity: 65, banner_overlay_opacity: 0 } }
    } }, as: :json
    assert_response :success
    assert_equal 100, @section.reload.media_overlay_value("banner", "opacity", "tablet")
    assert_equal 0, @section.media_overlay_value("image", "opacity", "tablet")
    assert_equal 65, @section.media_overlay_value("image", "opacity", "mobile")
    assert_includes response.parsed_body.fetch("style_variables"), "--mobile-banner-tint-opacity: 0.0"
    PagePublicationService.new(page: @page).call
    assert_equal @section.layout_settings, @page.sections.published.first.layout_settings
    assert_equal @section.responsive_settings, @page.sections.published.first.responsive_settings
    patch admin_page_section_path(@page, @section), params: { section: { responsive_settings: { mobile: { image_overlay_opacity: "" } } } }, as: :json
    assert_response :success
    assert_equal 0, @section.reload.media_overlay_value("image", "opacity", "mobile")
  end

  test "invalid CSS and percentages cannot change stored overlays" do
    [{ banner_overlay_opacity: -1 }, { image_overlay_opacity: 101 }, { image_overlay_opacity: "NaN" },
     { image_overlay_color: "url(https://example.test)" }, { banner_overlay_color: "#fff;display:none" },
     { responsive_settings: { mobile: { image_overlay_opacity: 101 } } },
     { responsive_settings: { tablet: { banner_overlay_color: "red" } } }].each do |settings|
      patch admin_page_section_path(@page, @section), params: { section: settings }, as: :json
      assert_response :unprocessable_entity
      assert_equal({}, @section.reload.layout_settings)
      assert_equal({}, @section.responsive_settings)
    end
  end

  test "overlays cannot be changed on another site" do
    other = Tenant.create!(name: "Outro", slug: "outro")
    other_page = other.pages.create!(name: "Outra", slug: "outra")
    other_section = other_page.sections.create!(section_type: "text", title: "Outro")
    patch admin_page_section_path(other_page, other_section), params: { section: { image_overlay_opacity: 100 } }, as: :json
    assert_response :not_found
    assert_equal({}, other_section.reload.layout_settings)
  end

  test "button text uses the existing authenticated AI endpoint and survives publication" do
    factory = ->(title:, body:) do
      assert_equal "Conheça meu trabalho", title
      assert_equal "", body
      Struct.new(:result) { def call = result }.new({ title_en: "Explore my work", body_en: "" })
    end
    TranslationService.stub(:new, factory) do
      post admin_translation_path, params: { translation: { title: "Conheça meu trabalho", body: "" } }, as: :json
      assert_response :success
      translated = response.parsed_body.fetch("title_en")
      patch admin_page_section_path(@page, @section), params: { section: { action_buttons_json: [{ label: "Conheça meu trabalho", label_en: translated, action: "contact", style: "secondary" }].to_json } }, as: :json
      assert_response :success
      assert_equal "Explore my work", @section.reload.action_buttons.first["label_en"]
    end
    PagePublicationService.new(page: @page).call
    assert_equal @section.action_buttons, @page.sections.published.first.action_buttons
  end

  test "translation failures return a message and anonymous requests cannot invoke AI" do
    service = Object.new
    def service.call = raise TranslationService::Error, "A tradução atingiu o limite da API."
    TranslationService.stub(:new, ->(**) { service }) do
      post admin_translation_path, params: { translation: { title: "Conheça meu trabalho", body: "" } }, as: :json
      assert_response :unprocessable_entity
      assert_equal "A tradução atingiu o limite da API.", response.parsed_body["error"]
    end
    sign_out @admin
    TranslationService.stub(:new, ->(**) { flunk "Anonymous visitor must not invoke translation" }) do
      post admin_translation_path, params: { translation: { title: "Texto", body: "" } }, as: :json
      assert_response :not_found
    end
  end
end
