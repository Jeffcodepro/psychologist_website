require "test_helper"

class Admin::CardPresentationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @tenant = Tenant.create!(name: "Composição", slug: "composicao", primary: true)
    @tenant.create_site_setting!(professional_name: "Profissional")
    sign_in @tenant.users.create!(admin: true, email: "cards-admin@example.test", password: "Composition-test-password-123!")
    @page = @tenant.pages.create!(name: "Página", slug: "pagina")
    @section = @page.sections.create!(section_type: "cards", title: "Título", body: "Texto")
    @card = @section.section_items.create!(title: "Card", body: "Resumo")
  end

  test "card presentation survives editing and publication without changing other devices" do
    settings = { desktop: { image_layout: "left", button_alignment: "right", button_position: "bottom" }, mobile: { image_layout: "background", button_alignment: "center", button_position: "top" } }
    patch admin_page_section_section_item_path(@page, @section, @card), params: { section_item: { card_settings: settings } }
    assert_response :redirect
    assert_equal 'background', @card.reload.card_value('image_layout', 'mobile')
    assert_equal 'left', @card.card_value('image_layout', 'tablet')
    PagePublicationService.new(page: @page).call
    assert_equal @card.card_settings, @page.sections.published.first.section_items.first.card_settings
    get admin_page_preview_frame_path(@page)
    assert_select '.compact-card[data-card-layout-mobile="background"][data-card-align-desktop="right"]'
    get edit_admin_page_section_section_item_path(@page, @section, @card)
    assert_select 'select[name="section_item[card_settings][mobile][image_layout]"] option[value="background"][selected]'
  end

  test "card tint is validated and published including zero opacity and independent mobile settings" do
    settings = { desktop: { image_layout: 'background', overlay_color: '#123456', overlay_opacity: 0, background_text_color: '#234567' }, mobile: { overlay_opacity: 80 } }
    patch admin_page_section_section_item_path(@page, @section, @card), params: { section_item: { card_settings: settings } }
    assert_response :redirect
    assert_equal '0', @card.reload.card_value('overlay_opacity').to_s
    assert_equal '#123456', @card.card_value('overlay_color', 'tablet')
    assert_equal '80', @card.card_value('overlay_opacity', 'mobile').to_s
    PagePublicationService.new(page: @page).call
    assert_equal @card.card_settings, @page.sections.published.first.section_items.first.card_settings
    get admin_page_preview_frame_path(@page)
    assert_select '[style*="--card-desktop-overlay-opacity: 0.0"][style*="--card-mobile-overlay-opacity: 0.8"]'
    [{ overlay_opacity: -1 }, { overlay_opacity: 101 }, { overlay_opacity: 'NaN' }, { overlay_color: 'red;display:none' }, { background_text_color: 'url(https://example.test)' }].each do |values|
      @card.card_settings = { desktop: values }
      assert_not @card.valid?
    end
  end

  test "invalid composition is rejected in model and controller" do
    [{ mobile: { image_layout: "url(javascript:bad)" } }, { laptop: {} }, [], { desktop: { injected: "value" } }].each do |settings|
      @card.card_settings = settings
      assert_not @card.valid?
    end
    patch admin_page_section_section_item_path(@page, @section, @card), params: { section_item: { card_settings: { desktop: { button_position: "absolute" } } } }
    assert_response :unprocessable_entity
    assert_equal({}, @card.reload.card_settings)
  end

  test "interleaved and background section choices are saved only for the selected device" do
    %w[media_between media_before_buttons media_background].each do |layout|
      patch admin_page_section_path(@page, @section), params: { section: { responsive_settings: { mobile: { media_layout: layout } } } }, as: :json
      assert_response :success
      assert_equal layout, response.parsed_body.fetch('media_layouts').fetch('mobile')
      assert_equal 'text_left', @section.reload.media_layout
    end
  end

  test "SEO templates use the owner name without overwriting saved metadata" do
    @page.update!(seo_title: "Título personalizado")
    get edit_admin_page_path(@page)
    assert_response :success
    assert_select '[data-controller="seo-editor"]', count: 2
    assert_select 'input[name="page[seo_title]"][value="Título personalizado"]'
    assert_select 'button', text: 'Usar modelo de título', count: 2
    get edit_admin_site_setting_path
    assert_response :success
    assert_select '[data-seo-editor-title-value="Profissional | Psicologia e psicoterapia"]'
  end
  test "card spacings are validated published and inherited without changing dimensions" do
    settings = { desktop: { text_padding: 8, title_body_gap: 26, image_text_gap: 34, button_gap: 20 }, mobile: { title_body_gap: 0 } }
    patch admin_page_section_section_item_path(@page, @section, @card), params: { section_item: { card_settings: settings } }
    assert_response :redirect
    assert_equal '0', @card.reload.card_value('title_body_gap', 'mobile').to_s
    assert_equal '26', @card.card_value('title_body_gap', 'tablet').to_s
    PagePublicationService.new(page: @page).call
    assert_equal @card.card_settings, @page.sections.published.first.section_items.first.card_settings
    get admin_page_preview_frame_path(@page)
    assert_select '.compact-card[style*="--card-desktop-image-text-gap: 34px"][style*="--card-mobile-title-body-gap: 0px"]'
    [{ image_text_gap: -1 }, { title_body_gap: 41 }, { text_padding: 'NaN' }, { button_gap: '12px; color:red' }].each do |values|
      @card.card_settings = { desktop: values }
      assert_not @card.valid?
    end
  end

end
