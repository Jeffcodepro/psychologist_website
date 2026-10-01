require "test_helper"
require "base64"

class Admin::CmsEditorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Teste", slug: "teste", primary: true)
    sign_in @tenant.users.create!(admin: true, email: "cms-test@example.test", password: "Local-test-password-123!")
    @page = @tenant.pages.create!(name: "Página de teste", slug: "pagina-teste")
    @section = @page.sections.create!(section_type: "hero", title: "Acolhimento", media_layout: "text_left")
  end

  test "editor and preview render fonts, responsive controls and cropping without errors" do
    get edit_admin_page_section_path(@page, @section)
    assert_response :success
    assert_select ".font-picker__option", count: FontCatalog::NAMES.size * 2
    assert_select 'select[name="section[responsive_settings][mobile][media_layout]"]'
    assert_select 'input[type="file"][hidden][name="section[image]"]', count: 1
    assert_select 'input[type="file"][hidden][name="section[banner]"]', count: 1
    get admin_page_preview_frame_path(@page)
    assert_response :success
    assert_includes response.body, "--mobile-title-size: 34px"
    assert_includes response.body, "--desktop-title-size: 48px"
  end

  test "updating mobile through preview preserves every other device and can restore inheritance" do
    @section.update!(responsive_settings: { tablet: { media_layout: "text_right" }, mobile: { image_zoom: 1.5 } })
    patch admin_page_section_path(@page, @section), params: { section: { responsive_settings: { mobile: { media_layout: "media_top" } } } }, as: :json
    assert_response :success
    assert_equal "text_left", @section.reload.media_layout
    assert_equal "text_right", @section.responsive_settings.dig("tablet", "media_layout")
    assert_equal 1.5, @section.responsive_settings.dig("mobile", "image_zoom")
    assert_includes response.parsed_body.fetch("style_variables"), "--mobile-media-order: 1"
    patch admin_page_section_path(@page, @section), params: { section: { responsive_settings: { mobile: { media_layout: "" } } } }, as: :json
    assert_response :success
    assert_equal "text_left", @section.reload.visual_value("media_layout", "mobile")
  end

  test "invalid responsive changes return errors and do not alter saved draft" do
    patch admin_page_section_path(@page, @section), params: { section: { responsive_settings: { mobile: { image_zoom: 4 } } } }, as: :json
    assert_response :unprocessable_entity
    assert_equal({}, @section.reload.responsive_settings)
  end

  test "each card retains its own uploaded image and crop after publication and removal" do
    @section.update!(section_type: "cards")
    png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=")
    file = Tempfile.new(["card", ".png"])
    file.binmode
    file.write(png)
    file.rewind
    upload = Rack::Test::UploadedFile.new(file.path, "image/png")
    post admin_page_section_section_items_path(@page, @section), params: { section_item: { title: "Card com foto", image: upload, image_position_x: 20, image_position_y: 75, image_zoom: 1.4, image_shape: "circle" } }
    assert_response :redirect
    card = @section.section_items.last
    assert card.image.attached?
    assert_equal 20, card.image_position_x
    other = @section.section_items.create!(title: "Sem foto")
    assert_not other.image.attached?
    PagePublicationService.new(page: @page).call
    published = @page.sections.published.first.section_items.find_by!(title: "Card com foto")
    assert_equal card.image.blob_id, published.image.blob_id
    assert_equal "circle", published.image_shape
    assert_equal card.image_zoom, published.image_zoom
    get edit_admin_page_section_section_item_path(@page, @section, card)
    assert_response :success
    assert_select '[data-controller="image-cropper"]'
    patch admin_page_section_section_item_path(@page, @section, card), params: { section_item: { remove_image: "1" } }
    assert_response :redirect
    assert_not card.reload.image.attached?
    assert published.reload.image.attached?
    sign_out :user
    get public_page_path(slug: @page.slug, locale: nil)
    assert_response :success
    assert_select ".psychology-card__image", count: 1
    assert_includes response.body, "--card-image-zoom: 1.4"
  ensure
    file&.close!
  end

  test "a page can be created using only its name" do
    post admin_pages_path, params: { page: { name: "Uma nova página" } }
    assert_response :redirect
    page = Page.find_by!(slug: "uma-nova-pagina")
    assert_nil page.description
  end

  test "page list, new section and item screens render" do
    get admin_pages_path
    assert_response :success
    get new_admin_page_path
    assert_response :success
    get new_admin_page_section_path(@page)
    assert_response :success
    get new_admin_page_section_section_item_path(@page, @section)
    assert_response :success
  end
end
