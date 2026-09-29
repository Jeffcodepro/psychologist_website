require "test_helper"

class ContactRequestsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Teste", slug: "teste", primary: true)
    @page = TenantProvisioner.ensure_contact_page!(@tenant)
    @form = @page.sections.published.first
  end

  def submit(details)
    post contact_requests_path, params: { form_section_id: @form.id, contact_request: { answers: details.except(:website), website: details[:website] } }
  end

  def valid_details
    { full_name: "Pessoa de teste", phone: "(11) 99999-1234", email: " TESTE@example.test ", message: "Gostaria de combinar uma primeira conversa." }
  end

  test "contact is saved and the visitor sees confirmation without sending any external message" do
    assert_difference "ContactRequest.count", 1 do
      submit valid_details
    end
    assert_response :success
    assert_select 'turbo-frame .appointment-form__success'
    assert_equal "teste@example.test", ContactRequest.last.email
    assert_no_difference "ContactRequest.count" do
      submit valid_details
    end
    assert_response :unprocessable_entity
  end

  test "invalid details remain editable and spam does not create a request" do
    assert_no_difference "ContactRequest.count" do
      submit valid_details.merge(phone: "12", email: "inválido")
    end
    assert_response :unprocessable_entity
    assert_select '.appointment-form__errors'
    assert_select 'input[name="contact_request[answers][full_name]"][value="Pessoa de teste"]'
    assert_no_difference "ContactRequest.count" do
      submit valid_details.merge(website: "spam.example")
    end
    assert_response :success
  end

  test "received requests are only accessible after login and can be read and deleted" do
    request = @tenant.contact_requests.create!(valid_details)
    get admin_contact_request_path(request)
    assert_response :not_found
    sign_in @tenant.users.create!(admin: true, email: "contact-admin@example.test", password: "Local-test-password-123!")
    get admin_contact_requests_path
    assert_response :success
    assert_select 'a', text: 'Abrir mensagem'
    get admin_contact_request_path(request)
    assert_response :success
    assert request.reload.read_at
    assert_difference "ContactRequest.count", -1 do
      delete admin_contact_request_path(request)
    end
    assert_redirected_to admin_contact_requests_path(locale: "pt-BR")
  end
end
