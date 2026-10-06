require "test_helper"

class Admin::LayoutSettingsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Layout", slug: "layout", primary: true)
    @tenant.create_site_setting!(professional_name: "Profissional")
    @admin = @tenant.users.create!(admin: true, email: "spacing@example.test", password: "Layout-test-password-123!")
    @page = @tenant.pages.create!(name: "Contato", slug: "contato")
    @section = @page.sections.create!(section_type: "contact", title: "Entre em contato", body: "Envie sua mensagem")
    sign_in @admin
  end

  test "form layout and spacing are saved, published and inherited independently" do
    patch admin_page_section_path(@page, @section), params: { section: { form_position: "right", form_width: "compact", form_vertical_alignment: "bottom", content_gap: 36, paragraph_spacing: 24,
      responsive_settings: { mobile: { form_position: "before_text", content_gap: 12 } } } }, as: :json
    assert_response :success
    assert_equal 'right', @section.reload.form_position
    assert_equal 'bottom', @section.form_vertical_alignment
    assert_includes response.parsed_body['style_variables'], '--desktop-form-vertical-align: end'
    assert_equal 'before_text', @section.visual_value('form_position', 'mobile')
    assert_equal 'right', @section.visual_value('form_position', 'tablet')
    assert_equal 12, @section.visual_value('content_gap', 'mobile')
    patch admin_page_section_path(@page, @section), params: { section: { responsive_settings: { tablet: { cards_gap: 30 } } } }, as: :json
    assert_response :success
    assert_equal 12, @section.reload.visual_value('content_gap', 'mobile')
    assert_includes response.parsed_body['style_variables'], '--desktop-content-gap: 36px'
    PagePublicationService.new(page: @page).call
    published = @page.sections.published.first
    assert_equal @section.layout_settings, published.layout_settings
    get edit_admin_page_section_path(@page, @section)
    assert_select 'select[name="section[form_position]"] option[selected][value="right"]'
    assert_select 'input[name="section[responsive_settings][mobile][content_gap]"][value="12"]'
    sign_out @admin
    get contact_path
    assert_response :success
    assert_select '.flexible-section__contact-layout > .flexible-section__form form', count: 1
    assert_select '.flexible-section__copy form', count: 0
    assert_select '[data-move-field="form"]', count: 0
  end

  test "invalid layout and CSS values are rejected without modifying saved settings" do
    [{ content_gap: -1 }, { section_padding_top: 241 }, { content_gap: 'NaN' }, { form_vertical_alignment: 'unsafe' }, { form_position: 'absolute' }, { form_width: 'url(https://example.test)' },
      { responsive_settings: { mobile: { content_gap: 9000 } } }].each do |settings|
      patch admin_page_section_path(@page, @section), params: { section: settings }, as: :json
      assert_response :unprocessable_entity
      assert_equal({}, @section.reload.layout_settings)
    end
  end

  test "another site cannot change form placement" do
    other = Tenant.create!(name: "Outro", slug: "outro")
    section = other.pages.create!(name: "Contato", slug: "contato").sections.create!(section_type: 'contact', title: 'Contato')
    patch admin_page_section_path(section.page, section), params: { section: { form_position: 'left' } }, as: :json
    assert_response :not_found
    assert_equal({}, section.reload.layout_settings)
  end
  test "independent spacings preserve defaults accept zero and publish responsive values" do
    assert_equal 18, @section.visual_value('title_body_gap')
    assert_equal 32, @section.visual_value('image_text_gap')
    patch admin_page_section_path(@page, @section), params: { section: {
      title_body_gap: 0, image_text_gap: 64, buttons_gap: 26, cards_content_gap: 46, form_gap: 52,
      section_padding_inline: 12, responsive_settings: { mobile: { image_text_gap: 10, title_body_gap: 8 } }
    } }, as: :json
    assert_response :success
    @section.reload
    assert_equal 0, @section.visual_value('title_body_gap', 'tablet')
    assert_equal 8, @section.visual_value('title_body_gap', 'mobile')
    assert_equal 64, @section.visual_value('image_text_gap', 'tablet')
    PagePublicationService.new(page: @page).call
    assert_equal @section.layout_settings, @page.sections.published.first.layout_settings
    patch admin_page_section_path(@page, @section), params: { section: { title_body_gap: '', responsive_settings: { mobile: { title_body_gap: '' } } } }, as: :json
    assert_response :success
    assert_equal 18, @section.reload.visual_value('title_body_gap', 'mobile')
    [{ image_text_gap: -1 }, { buttons_gap: 161 }, { form_gap: 'calc(100px)' }, { responsive_settings: { mobile: { title_body_gap: 900 } } }].each do |settings|
      patch admin_page_section_path(@page, @section), params: { section: settings }, as: :json
      assert_response :unprocessable_entity
    end
  end

end
