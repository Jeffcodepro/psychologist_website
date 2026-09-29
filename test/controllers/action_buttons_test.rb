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
    get admin_page_preview_frame_path(@page, locale: 'en')
    assert_response :success
    assert_select '.section-actions .site-action', count: 2
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
end
