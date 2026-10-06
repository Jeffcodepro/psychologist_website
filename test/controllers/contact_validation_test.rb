require "test_helper"

class ContactValidationTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create!(name: "Validação", slug: "input-validation", primary: true)
    @form = TenantProvisioner.ensure_contact_page!(@tenant).sections.published.first
    @details = { full_name: "Ana Silva", phone: "912345678", email: " ANA+site@example.test ", message: "Contato de Portugal." }
  end

  def submit(details, country = "PT")
    post contact_requests_path, params: { form_section_id: @form.id,
      contact_request: { answers: details, phone_countries: { phone: country } } }
  end

  test "country selection is accepted and the normalized value reaches the saved message" do
    assert_difference "ContactRequest.count", 1 do
      submit @details
    end
    assert_response :success
    assert_equal "+351912345678", ContactRequest.last.phone
    assert_equal "ana+site@example.test", ContactRequest.last.email
  end

  test "server rejects invalid data bypassing JavaScript and retains country and entered values" do
    assert_no_difference "ContactRequest.count" do
      submit @details.merge(full_name: "Ana", phone: "12", email: "ana@localhost")
    end
    assert_response :unprocessable_entity
    assert_select ".appointment-form__errors li", count: 3
    assert_select 'select[data-phone-country] option[selected][value="PT"]'
    assert_select 'input[type="tel"][value="12"]'
  end

  test "tampered region cannot bypass phone validation" do
    assert_no_difference "ContactRequest.count" do
      submit @details, "<script>"
    end
    assert_response :unprocessable_entity
  end
  test "English locale localizes country labels and validation messages without URL parameters" do
    post language_preference_path, params: { language: "en", return_to: contact_path }
    get contact_path
    assert_response :success
    assert_select 'select[data-phone-country] option[value="BR"]', text: '🇧🇷 Brazil (+55)'
    assert_select 'form[data-contact-validation-language-value="en"]'
    submit @details.merge(full_name: "Ana", email: "ana@localhost")
    assert_response :unprocessable_entity
    assert_select '.appointment-form__errors', text: /first and last name/
    assert_select '.appointment-form__errors', text: /valid email address/
  end

  test "malformed parameter structures return a client error without saving a contact" do
    ["invalid", ["invalid"], { answers: [{ full_name: "Ana Silva" }] }, { phone_countries: [{ phone: "PT" }] }].each do |payload|
      assert_no_difference "ContactRequest.count" do
        post contact_requests_path, params: { form_section_id: @form.id, contact_request: payload }
      end
      assert_response :bad_request
    end
  end

end
