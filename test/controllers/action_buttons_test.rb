require 'test_helper'
class ActionButtonsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @tenant = Tenant.create!(name: 'Botões', slug: 'botoes', primary: true)
    @settings = @tenant.create_site_setting!(professional_name: 'Botões')
    @user = @tenant.users.create!(admin: true, email: 'buttons@example.test', password: 'Button-password-123!')
    @page = TenantProvisioner.ensure_contact_page!(@tenant)
    @section = @page.sections.draft.first
    @button = { 'label' => 'Conheça', 'label_en' => 'Explore', 'action' => 'contact', 'value' => '', 'style' => 'primary' }
    sign_in @user
  end

  test 'owner can add remove order and move buttons in any section without forced CTA' do
    patch admin_page_section_path(@page, @section), params: { section: { action_buttons_json: [@button, @button.merge('label' => 'Ligar', 'action' => 'phone', 'value' => '+5511999991234')].to_json, buttons_position: 'between_text', buttons_alignment: 'right' } }, as: :json
    assert_response :success
    assert_equal ['Conheça', 'Ligar'], @section.reload.action_buttons.map { |b| b['label'] }
    post admin_language_preference_path, params: { language: "en" }, as: :json
    get admin_page_preview_frame_path(@page)
    assert_response :success
    assert_select '.section-actions--inline .site-action', count: 2
    assert_includes response.body, '--desktop-buttons-collection-display: none'
    assert_select '.section-actions a[href*="/admin/pages/"]', text: 'Explore'
    assert_select '.element-grip[data-move-field="buttons"]'
    other = @page.sections.create!(section_type: 'text', title: 'Outro trecho')
    patch swap_fields_admin_page_sections_path(@page), params: { source_id: @section.id, target_id: other.id, field: 'buttons' }
    assert_response :redirect
    assert_empty @section.reload.action_buttons
    assert_equal 2, other.reload.action_buttons.size
    patch admin_page_section_path(@page, other), params: { section: { action_buttons_json: '[]' } }
    assert_response :redirect
    assert_empty other.reload.action_buttons
    assert_empty @page.sections.create!(section_type: 'hero').action_buttons
  end

  test 'header and footer buttons can be independently removed or changed' do
    patch admin_site_setting_path, params: { site_setting: { header_actions_json: [@button].to_json, footer_actions_json: [@button.merge('action' => 'whatsapp', 'value' => '+55 11 99623-3656')].to_json } }
    assert_response :redirect
    get admin_page_preview_frame_path(@page)
    assert_select '.site-footer__configured-actions a[href="https://wa.me/5511996233656"]'
    patch admin_site_setting_path, params: { site_setting: { header_actions_json: '[]' } }
    assert_response :redirect
    assert_empty @settings.reload.header_actions
    assert_equal 1, @settings.footer_actions.size
  end

  test 'unsafe destinations and pages from another client are rejected' do
    other = Tenant.create!(name: 'Other', slug: 'other')
    foreign = other.pages.create!(name: 'Foreign')
    [['url', 'javascript:alert(1)'], ['url', 'https://user:password@example.com'], ['email', "a@example.com\r\nBcc:evil@example.com"], ['page', foreign.id.to_s], ['anchor', 'x" onclick="evil']].each do |action, value|
      patch admin_page_section_path(@page, @section), params: { section: { action_buttons_json: [@button.merge('action' => action, 'value' => value)].to_json } }, as: :json
      assert_response :unprocessable_entity
    end
    assert_empty @section.reload.action_buttons
  end

  test 'buttons publish with the section and respect responsive placement' do
    patch admin_page_section_path(@page, @section), params: { section: { action_buttons_json: [@button].to_json, responsive_settings: { mobile: { buttons_position: 'before_text', buttons_alignment: 'center' } } } }, as: :json
    assert_response :success
    assert_includes response.parsed_body['style_variables'], '--mobile-buttons-order: 0'
    PagePublicationService.new(page: @page).call
    assert_equal @section.reload.action_buttons, @page.sections.published.first.action_buttons
    sign_out @user
    get contact_path
    assert_response :success
    assert_select '.section-actions a[href*="/contato"]', text: 'Conheça'
    assert_select '.section-actions a[href*="/admin/"]', count: 0
  end
  test 'custom appearance and section destinations survive publication and republishing' do
    target_page = @tenant.pages.create!(name: 'Sobre', slug: 'sobre')
    target = target_page.sections.create!(section_type: 'text', title: 'Formação', position: 1)
    custom = @button.merge('action' => 'section', 'value' => target.navigation_key, 'style' => 'custom', 'background_color' => '#17695b', 'text_color' => '#ffffff', 'size' => 'large', 'shape' => 'rounded')
    patch admin_page_section_path(@page, @section), params: { section: { action_buttons_json: [custom].to_json } }, as: :json
    assert_response :success
    get admin_page_preview_frame_path(@page)
    assert_select ".section-actions a[href='#{admin_page_preview_path(target_page, focus: target.navigation_key)}']"
    get admin_page_preview_path(target_page, focus: target.navigation_key)
    assert_select "iframe[src$='##{target.navigation_anchor}']"
    PagePublicationService.new(page: @page).call
    sign_out @user
    get contact_path
    assert_select '.section-actions a', count: 0
    PagePublicationService.new(page: target_page).call
    2.times do
      get contact_path
      assert_select ".section-actions a[href='/sobre##{target.navigation_anchor}'][style*='#17695b'].site-action--large.site-action--rounded", text: 'Conheça'
      get public_page_path(slug: target_page.slug)
      assert_select "section[id='#{target.navigation_anchor}']", count: 1
      target.update!(position: 3, title: 'Formação atualizada')
      PagePublicationService.new(page: target_page).call
    end
  end

  test 'deleting a destination does not break editing or publication of referring pages' do
    target_page = @tenant.pages.create!(name: 'Destino', slug: 'destino')
    target = target_page.sections.create!(section_type: 'text', title: 'Trecho')
    @section.update!(action_buttons: [@button.merge('action' => 'section', 'value' => target.navigation_key)])
    PagePublicationService.new(page: target_page).call
    PagePublicationService.new(page: @page).call
    target.destroy!
    PagePublicationService.new(page: target_page).call
    patch admin_page_section_path(@page, @section), params: { section: { title: 'Título atualizado' } }, as: :json
    assert_response :success
    PagePublicationService.new(page: @page).call
    assert_empty @page.sections.published.first.action_buttons
    sign_out @user
    get contact_path
    assert_response :success
    assert_select '.section-actions a', count: 0
  end

  test 'unsafe custom styles and foreign section destinations are rejected' do
    other = Tenant.create!(name: 'Outro', slug: 'outro')
    foreign = other.pages.create!(name: 'Página').sections.create!(section_type: 'text')
    [{ 'action' => 'section', 'value' => foreign.navigation_key }, { 'style' => 'custom', 'background_color' => 'url(https://evil.example)', 'text_color' => '#ffffff' }, { 'size' => 'giant' }, { 'shape' => 'x;display:none' }].each do |attrs|
      patch admin_page_section_path(@page, @section), params: { section: { action_buttons_json: [@button.merge(attrs)].to_json } }, as: :json
      assert_response :unprocessable_entity
    end
    assert_empty @section.reload.action_buttons
  end

  test 'standalone button blocks can be added to any page without text' do
    get new_admin_page_section_path(@page, preset: 'buttons')
    assert_response :success
    assert_select '[data-section-form-tabs-initial-value="buttons"]'
    post admin_page_sections_path(@page), params: { section: { section_type: 'cta', position: 9, action_buttons_json: [@button].to_json } }
    assert_response :redirect
    created = @page.sections.draft.order(:id).last
    assert_equal 'cta', created.section_type
    assert_equal [@button], created.action_buttons
    PagePublicationService.new(page: @page).call
  end

end
