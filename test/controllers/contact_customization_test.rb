require "test_helper"

class ContactCustomizationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @tenant = Tenant.create!(name: "Teste", slug: "teste", primary: true, contact_recipient: "recipient@example.test")
    @user = @tenant.users.create!(email: "form-admin@example.test", password: "Strong-password-123!", admin: true)
    @page = TenantProvisioner.ensure_contact_page!(@tenant)
    @draft = @page.sections.draft.first
    @fields = [
      { "key" => "topic", "type" => "select", "label" => "Assunto", "label_en" => "Topic", "width" => "half", "required" => true, "options" => ["Consulta", "Dúvida"] },
      { "key" => "email", "type" => "email", "label" => "E-mail", "width" => "half", "required" => true },
      { "key" => "details", "type" => "textarea", "label" => "Detalhes", "width" => "full", "required" => false }
    ]
  end

  test "fields save in order and only publication changes the public form" do
    sign_in @user
    get edit_admin_page_section_path(@page, @draft)
    assert_response :success
    assert_select '[data-controller="form-designer"]'
    patch admin_page_section_path(@page, @draft), params: { section: { form_fields_json: @fields.to_json } }
    assert_response :redirect
    assert_equal @fields, @draft.reload.form_fields
    assert_equal 'full_name', @page.sections.published.first.effective_form_fields.first['key']
    PagePublicationService.new(page: @page).call
    sign_out @user
    get contact_path(locale: 'en')
    assert_response :success
    assert_select '.contact-fields .appointment-form__field', count: 3
    assert_select '.contact-fields__half', count: 2
    assert_select 'label', text: 'Topic *'
    assert_select 'input[name="contact_request[answers][full_name]"]', count: 0
    assert_select '.contact-fields select', count: 1
  end

  test "published form validates on the server and stores a snapshot of custom answers" do
    @draft.update!(form_fields: @fields)
    PagePublicationService.new(page: @page).call
    form = @page.sections.published.first
    assert_no_difference 'ContactRequest.count' do
      post contact_requests_path, params: { form_section_id: form.id, contact_request: { answers: { topic: 'Unlisted', email: 'invalid' } } }
    end
    assert_response :unprocessable_entity
    assert_select '.appointment-form__errors'
    assert_difference 'ContactRequest.count', 1 do
      post contact_requests_path, params: { form_section_id: form.id, contact_request: { tenant_id: 123456, answers: { topic: 'Consulta', email: 'visitor@example.test', details: 'Uma pergunta', unlisted: 'ignore' } } }
    end
    assert_response :success
    contact = ContactRequest.last
    assert_equal @tenant.id, contact.tenant_id
    assert_equal @fields, contact.form_snapshot
    assert_not contact.answers.key?('unlisted')
    assert_equal 'visitor@example.test', contact.email
    assert_equal 'Uma pergunta', contact.message
    @draft.update!(form_fields: ContactFormSchema::DEFAULT_FIELDS)
    assert_equal @fields, contact.reload.form_snapshot
    message = ContactMailer.with(contact: contact).notification
    assert_equal ['recipient@example.test'], message.to
    assert_equal ['visitor@example.test'], message.reply_to
    assert_includes message.text_part.body.decoded, 'Assunto: Consulta'
  end

  test "draft or foreign form identifiers cannot accept submissions" do
    other = Tenant.create!(name: 'Outro', slug: 'outro')
    foreign = TenantProvisioner.ensure_contact_page!(other).sections.published.first
    [@draft.id, foreign.id].each do |id|
      assert_no_difference 'ContactRequest.count' do
        post contact_requests_path, params: { form_section_id: id, contact_request: { answers: { email: 'visitor@example.test' } } }
      end
      assert_response :not_found
    end
  end

  test "malformed form schemas and unsafe typography cannot change the draft" do
    sign_in @user
    ['not-json', '{}', [{ key: 'unsafe', label: 'Campo', type: 'file', required: true, width: 'full' }].to_json].each do |schema|
      patch admin_page_section_path(@page, @draft), params: { section: { form_fields_json: schema } }, as: :json
      assert_response :unprocessable_entity
    end
    patch admin_page_section_path(@page, @draft), params: { section: { title_font_weight: 900, body_font_style: 'url(evil)' } }, as: :json
    assert_response :unprocessable_entity
    patch admin_page_section_path(@page, @draft), params: { section: { title_font_family: 'fraunces', title_font_weight: 700, title_font_style: 'italic', title_line_height: 1.4, body_letter_spacing: 0.2, responsive_settings: { mobile: { title_font_family: 'sora', title_font_weight: '400', title_line_height: '1.6' } } } }, as: :json
    assert_response :success
    assert_includes response.parsed_body['style_variables'], '--mobile-title-font-weight: 400'
    PagePublicationService.new(page: @page).call
    assert_equal 'fraunces', @page.sections.published.first.title_font_family
    assert_equal 'sora', @page.sections.published.first.visual_value('title_font_family', 'mobile')
  end
end
