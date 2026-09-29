require "test_helper"

class ResponsiveSectionTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(name: "Teste", slug: "teste", primary: true)
    @page = @tenant.pages.create!(name: "Página de teste", slug: "pagina-teste")
    @section = @page.sections.create!(section_type: "hero", media_layout: "text_left", title_font_size_desktop: 52)
  end

  test "mobile adjustments preserve desktop and tablet and survive publication" do
    @section.update!(responsive_settings: { mobile: { media_layout: "media_top", title_font_size: 28, image_zoom: 1.8 } })
    assert_equal "text_left", @section.visual_value("media_layout")
    assert_equal "text_left", @section.visual_value("media_layout", "tablet")
    assert_equal "media_top", @section.visual_value("media_layout", "mobile")
    assert_equal 52, @section.visual_value("title_font_size")
    PagePublicationService.new(page: @page).call
    published = @page.sections.published.first
    assert_equal @section.responsive_settings, published.responsive_settings
    assert_equal 28, published.visual_value("title_font_size", "mobile")
  end

  test "blank overrides restore inheritance without discarding zero" do
    @section.update!(responsive_settings: { mobile: { image_position_x: "0", media_layout: "", banner_overlay: "0" } })
    assert_equal "text_left", @section.visual_value("media_layout", "mobile")
    assert_equal "0", @section.visual_value("image_position_x", "mobile")
    assert_equal "0", @section.visual_value("banner_overlay", "mobile")
  end

  test "invalid responsive CSS values and unknown devices are rejected" do
    [{ mobile: { title_color: "red;display:none" } }, { mobile: { image_zoom: 5 } },
     { mobile: { title_font_family: "unknown" } }, { television: { visible: "false" } }].each do |settings|
      @section.responsive_settings = settings
      assert_not @section.valid?, settings.inspect
    end
  end
end
