require "test_helper"

class Admin::SectionWorkflowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Blocos", slug: "workflow", primary: true)
    @tenant.create_site_setting!(professional_name: "Autora")
    sign_in @tenant.users.create!(admin: true, email: "workflow@example.test", password: "Workflow-password-123!")
    @page = @tenant.pages.create!(name: "Artigo", content_kind: "article")
    @first = @page.sections.create!(section_type: "text", title: "Primeiro", position: 1)
    @second = @page.sections.create!(section_type: "text", title: "Segundo", position: 2)
    PagePublicationService.new(page: @page).call
  end

  test "blank anchors submitted from full forms never conflict and the block editor remains accessible" do
    @first.update_column(:anchor, "") # An existing row from production before normalization.
    2.times do
      post admin_page_sections_path(@page), params: { section: { section_type: "text", anchor: "", body: "Texto sem título" } }
      assert_response :redirect
      block = @page.sections.draft.order(:id).last
      assert_nil block.anchor
      get edit_admin_page_section_path(@page, block)
      assert_response :success
    end
    patch admin_page_section_path(@page, @first), params: { section: { anchor: "  ", body: "Revisado" } }
    assert_response :redirect
    assert_nil @first.reload.anchor
    PagePublicationService.new(page: @page).call
    assert_equal 4, @page.sections.published.count
  end

  test "duplicate nonempty anchors return a validation error instead of a database exception" do
    @first.update!(anchor: "introducao")
    assert_no_difference 'Section.count' do
      post admin_page_sections_path(@page), params: { section: { section_type: "text", anchor: "introducao", body: "Preservado" } }
      assert_response :unprocessable_entity
    end
    assert_select 'textarea[name="section[body]"]', text: "Preservado"
  end

  test "JSON section movement returns directly and updates drafts only including duplicate legacy positions" do
    @second.update_column(:position, 1)
    original = @page.sections.published.ordered.pluck(:id, :position)
    patch swap_positions_admin_page_sections_path(@page), params: { first_id: @first.id, second_id: @second.id }, as: :json
    assert_response :no_content
    assert_nil response.headers['Location']
    assert_equal [@second.id, @first.id], @page.sections.draft.ordered.pluck(:id)
    assert_equal [1, 2], @page.sections.draft.ordered.pluck(:position)
    assert_equal original, @page.sections.published.ordered.pluck(:id, :position)
  end

  test "reordering cannot reach another page tenant or published section" do
    other = @tenant.pages.create!(name: "Outra página").sections.create!(section_type: "text")
    [other, @page.sections.published.first].each do |target|
      patch swap_positions_admin_page_sections_path(@page), params: { first_id: @first.id, second_id: target.id }, as: :json
      assert_response :not_found
      assert_equal 1, @first.reload.position
    end
  end

  test "spacing preview renders actual unsaved values without saving and rejects invalid or foreign data" do
    old = @first.attributes
    assert_no_difference ['Section.count', 'ContactRequest.count'] do
      post layout_preview_admin_page_section_path(@page, @first), params: { section: {
        title_body_gap: 70, body: "Primeiro\n\nSegundo", image_text_gap: 58,
        responsive_settings: { mobile: { title_body_gap: 29 } }, publication_state: "published", page_id: 1 } }
      assert_response :success
    end
    assert_select '[data-section-frame-id=?]', @first.id.to_s
    assert_includes response.body, '--desktop-title-body-gap: 70px'
    assert_includes response.body, '--mobile-title-body-gap: 29px'
    assert_select '.section-body p', count: 2
    assert_equal old, @first.reload.attributes
    post layout_preview_admin_page_section_path(@page, @first), params: { section: { title_body_gap: -10 } }
    assert_response :unprocessable_entity
    post layout_preview_admin_page_section_path(@page, @page.sections.published.first), params: { section: { title_body_gap: 70 } }
    assert_response :not_found
    assert_no_difference 'Section.count' do
      post layout_preview_admin_page_sections_path(@page), params: { section: { title: "Ainda não salvo", body: "Uma prévia", section_padding_top: 70 } }
      assert_response :success
      assert_includes response.body, 'Ainda não salvo'
    end
  end
end
