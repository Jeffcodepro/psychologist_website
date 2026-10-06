require "test_helper"

class ContactIdentityTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(name: "Validação", slug: "validation", primary: true)
    @section = TenantProvisioner.ensure_contact_page!(@tenant).sections.published.first
  end

  def contact(values = {}, countries = {})
    model = @tenant.contact_requests.new
    model.assign_form(@section, { "full_name" => "Maria da Silva", "phone" => "(11) 99999-1234", "email" => " MARIA+site@example.com ", "message" => "Uma mensagem." }.merge(values), countries: countries)
    model
  end

  test "valid international numbers are stored in E164 in both answers and contact" do
    { "BR" => ["(11) 99999-1234", "+5511999991234"], "PT" => ["912 345 678", "+351912345678"],
      "US" => ["202-555-0123", "+12025550123"], "GB" => ["020 7946 0018", "+442079460018"],
      "IS" => ["6111234", "+3546111234"] }.each do |region, (number, canonical)|
      model = contact({ "phone" => number }, { "phone" => region })
      assert model.valid?, "#{region}: #{model.errors.full_messages}"
      assert_equal canonical, model.phone
      assert_equal canonical, model.answers["phone"]
      assert_equal "maria+site@example.com", model.email
    end
  end

  test "invalid country numbers and disguised text are rejected" do
    [["123", "BR"], ["1199999123456789", "BR"], ["+12025550123", "BR"], ["11999991234", "ZZ"],
      ["abc11999991234", "BR"], ["+5511999991234 ext 2", "BR"]].each do |number, region|
      model = contact({ "phone" => number }, { "phone" => region })
      assert_not model.valid?, "Accepted #{number} / #{region}"
      assert_includes model.errors.full_messages.join, "país selecionado"
    end
  end

  test "international paste works without country metadata and legacy national number defaults to Brazil" do
    assert contact("phone" => "+442079460018").valid?
    assert contact.valid?
  end

  test "names support Unicode compound names and reject missing surnames numbers and markup" do
    ["João da Silva", "Anne-Marie O’Neill", "José D'Ávila", "李 小龍", "  Ana   Maria  "].each { |name| assert contact("full_name" => name).valid?, name }
    ["João", "João 123", "Ana <script>", "A- Silva", "😀 Silva"].each { |name| assert_not contact("full_name" => name).valid?, name }
  end

  test "email shape is strict without pretending to verify ownership or DNS" do
    %w[ana@example.com ana+contato@sub.example.com ana@example.test].each { |email| assert contact("email" => email).valid?, email }
    ["ana", "ana@localhost", ".ana@example.com", "ana..silva@example.com", "ana@-example.com", "ana@example..com", "ana@example.com\r\nBcc:x@example.com", "a" * 65 + "@example.com"].each do |email|
      assert_not contact("email" => email).valid?, email
    end
  end

  test "custom semantic name and optional telephone are validated without requiring absent fields" do
    @section.form_fields = [ { "key" => "visitor", "type" => "name", "label" => "Nome", "required" => true, "width" => "full" },
      { "key" => "optional_phone", "type" => "tel", "label" => "Telefone", "required" => false, "width" => "full" } ]
    model = @tenant.contact_requests.new
    model.assign_form(@section, { "visitor" => "Ana Silva", "optional_phone" => "" })
    assert model.valid?, model.errors.full_messages.inspect
    assert_equal "Ana Silva", model.full_name
    model.assign_form(@section, { "visitor" => "Ana", "optional_phone" => "12" })
    assert_not model.valid?
    assert_equal 2, model.errors.count
  end

  test "old submissions remain readable without rewriting their historical data" do
    model = contact
    model.save!
    model.update_columns(full_name: "Ana", phone: "123", answers: model.answers.merge("full_name" => "Ana", "phone" => "123"))
    assert model.reload.update(read_at: Time.current)
    assert_equal "123", model.phone
    assert_equal "Ana", model.full_name
    model.answers = model.answers.merge("email" => "broken")
    assert_not model.valid?
  end
end
