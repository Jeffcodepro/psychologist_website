require "test_helper"
class SiteEmailUpdateTest < ActiveSupport::TestCase
  test "changing login and recipient preserves the password and leaves other sites intact" do
    site = Tenant.create!(name: "Email", slug: "email-change", contact_recipient: "old@example.test")
    admin = site.users.create!(admin: true, email: "old@example.test", password: "Email-test-password-123!")
    password = admin.encrypted_password
    SiteEmailUpdate.call(tenant: site, email: "new@example.test")
    assert_equal "new@example.test", admin.reload.email
    assert_equal password, admin.encrypted_password
    assert_equal "new@example.test", site.reload.delivery_recipient
    assert_raises(ActiveRecord::RecordInvalid) { SiteEmailUpdate.call(tenant: site, email: "bad email") }
    assert_equal "new@example.test", admin.reload.email
    assert_equal "new@example.test", site.reload.delivery_recipient
  end
  test "multiple admins require an explicit account and another site cannot be modified" do
    site = Tenant.create!(name: "Email", slug: "email-multiple", contact_recipient: "old@example.test")
    2.times { |n| site.users.create!(admin: true, email: "email-admin-#{n}@example.test", password: "Email-test-password-123!") }
    assert_raises(ArgumentError) { SiteEmailUpdate.call(tenant: site, email: "new@example.test") }
    assert_equal "old@example.test", site.reload.delivery_recipient
    assert_raises(ActiveRecord::RecordNotFound) { SiteEmailUpdate.call(tenant: site, email: "new@example.test", admin_id: 0) }
  end
end
