require "test_helper"
require "base64"

class Admin::FlexibleMediaTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Teste", slug: "teste", primary: true)
    sign_in @tenant.users.create!(admin: true, email: "media-test@example.test", password: "Local-test-password-123!")
    @page = @tenant.pages.create!(name: "Mídia de teste", slug: "midia-teste")
    @section = @page.sections.create!(section_type: "text", title: "Conteúdo flexível", body: "Meu parágrafo", body_en: "My paragraph")
    @files = []
  end

  teardown { @files.each(&:close!) }

  def image_upload
    file = Tempfile.new(["media", ".png"])
    file.binmode
    file.write(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII="))
    file.rewind
    @files << file
    Rack::Test::UploadedFile.new(file.path, "image/png")
  end

  test "a text section can publish independent photo and banner sequences with crop and adjustments" do
    patch admin_page_section_path(@page, @section), params: { section: {
      image: image_upload, banner: image_upload, banner_layout: "background", media_interval_seconds: 7,
      media_adjustments: { image: { rotation: 15, flip_x: -1, saturation: 0 } },
      section_slides_attributes: {
        "0" => { role: "image", position: 1, image: image_upload, image_position_x: 24, image_zoom: 1.7,
                     media_adjustments: { image: { brightness: 120 } } },
        "1" => { role: "banner", position: 1, image: image_upload },
        "2" => { role: "image", position: 2, image: "" }
      }
    } }
    assert_response :redirect
    @section.reload
    assert_equal 2, @section.section_slides.count
    assert @section.image.attached?
    assert @section.banner.attached?
    assert_equal 7, @section.media_interval_seconds
    PagePublicationService.new(page: @page).call
    published = @page.sections.published.first
    assert_equal 2, published.section_slides.count
    slide = @section.section_slides.find_by!(role: "image")
    published_slide = published.section_slides.find_by!(role: "image")
    assert_equal slide.image.blob_id, published_slide.image.blob_id
    assert_equal 24, published_slide.image_position_x
    assert_equal BigDecimal("1.7"), published_slide.image_zoom
    assert_equal "120", published_slide.media_adjustment("image", "brightness")
    sign_out :user
    get public_page_path(slug: @page.slug)
    assert_response :success
    assert_select '.section-frame--background .media-sequence', count: 2
    assert_select '.media-sequence__slide', count: 4
    assert_select '.media-sequence__pause', count: 2
    assert_select '[data-media-sequence-delay-value="7000"]', count: 2
    assert_includes response.body, "--media-rotation: 15.0deg"
    sign_in @tenant.users.first
    patch admin_page_section_path(@page, @section), params: { section: { section_slides_attributes: { "0" => { id: slide.id, _destroy: "1" } } } }
    assert_response :redirect
    assert_equal 1, @section.reload.section_slides.count
    assert published_slide.reload.image.attached?
  end

  test "cards and questions coexist in a FAQ without forced numbering" do
    @section.update!(section_type: "faq")
    @section.section_items.create!(title: "Como começar?", body: "Uma conversa.")
    post admin_page_section_section_items_path(@page, @section), params: { section_item: { item_kind: "card", title: "Apoio", body: "Um texto longo. " * 120 } }
    assert_response :redirect
    assert_equal 1, @section.section_items.cards.count
    assert_equal 1, @section.section_items.questions.count
    get edit_admin_page_section_path(@page, @section)
    assert_response :success
    assert_select '[data-tab="items"]', text: /Cards/
    assert_select '[data-tab="special_items"]', text: /Perguntas/
    get admin_page_preview_frame_path(@page)
    assert_response :success
    assert_select '.question__summary', text: /Como começar\?/
    assert_select '.compact-card__title', text: 'Apoio'
    assert_select '.psychology-card__number, .faq-item__number', count: 0
    assert_select '.card-reader-dialog'
    assert_select '.element-grip[data-move-field="body"]'
    assert_select '.element-grip[data-move-field="title"]'
  end

  test "every section type supports optional media and no empty photograph column" do
    Section::SECTION_TYPES.each do |type|
      @section.update!(section_type: type, use_profile_image: false)
      get admin_page_preview_frame_path(@page)
      assert_response :success
      assert_select '.flexible-section__media', count: 0
      get edit_admin_page_section_path(@page, @section)
      assert_response :success
      assert_select 'input[name="section[image]"]', count: 1
      assert_select 'input[name="section[banner]"]', count: 1
      assert_select '[data-tab="items"]'
      assert_select 'input[name="section[media_layout]"]', count: 4
    end
  end

  test "invalid sequence timing and image adjustments cannot change saved state" do
    patch admin_page_section_path(@page, @section), params: { section: { media_interval_seconds: 0, media_adjustments: { image: { rotation: 800, flip_x: 0 } } } }, as: :json
    assert_response :unprocessable_entity
    assert_equal 5, @section.reload.media_interval_seconds
    assert_equal({}, @section.media_adjustments)
  end

  test "moving a paragraph also moves its translation" do
    target = @page.sections.create!(section_type: "cta", body: "Outro texto", body_en: "Other text")
    patch swap_fields_admin_page_sections_path(@page), params: { source_id: @section.id, target_id: target.id, field: "body" }, as: :json
    assert_response :redirect
    assert_equal "Other text", @section.reload.body_en
    assert_equal "Meu parágrafo", target.reload.body
    assert_equal "My paragraph", target.body_en
  end
end
