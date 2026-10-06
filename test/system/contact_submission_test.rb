require "application_system_test_case"

class ContactSubmissionTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1200, 1000]

  setup do
    @tenant = Tenant.create!(name: "Contato", slug: "contact-browser", primary: true)
    @tenant.create_site_setting!(professional_name: "Contato")
    @form = TenantProvisioner.ensure_contact_page!(@tenant).sections.published.first
  end

  test "Turbo confirmation survives a full reload and a new tab" do
    visit contact_path
    fill_in "contact_#{@form.id}_full_name", with: "Visitante teste"
    fill_in "contact_#{@form.id}_phone", with: "11999991234"
    fill_in "contact_#{@form.id}_email", with: "browser@example.test"
    fill_in "contact_#{@form.id}_message", with: "Gostaria de uma conversa."
    click_button "Quero agendar uma conversa"
    assert_selector ".appointment-form__success", text: "Mensagem recebida"
    assert_no_selector "form.appointment-form"
    page.refresh
    assert_selector ".appointment-form__success", text: "Mensagem recebida"
    assert_no_selector "form.appointment-form"
    within_window open_new_window do
      visit contact_path
      assert_selector ".appointment-form__success", text: "Mensagem recebida"
      assert_no_selector "form.appointment-form"
    end
    assert_equal 1, @tenant.contact_requests.count
  end
end
