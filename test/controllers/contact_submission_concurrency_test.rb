require "test_helper"
require "timeout"

class ContactSubmissionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "simultaneous submissions from separate connections save only one contact" do
    tenant = Tenant.create!(name: "Simultaneous contact", slug: "concurrent-contact")
    ready, start = Queue.new, Queue.new
    threads = 2.times.map do
      Thread.new do
        Rails.application.executor.wrap do
          ApplicationRecord.connection_pool.with_connection do
            contact = ContactRequest.new(tenant_id: tenant.id, full_name: "Visitante Teste", phone: "11999991234",
              email: "simultaneous@example.test", message: "Teste simultâneo",
              request_fingerprint: ContactSubmissionGuard.fingerprint("203.0.113.1"))
            guard = ContactSubmissionGuard.new(contact_request: contact, session: {})
            ready << true
            start.pop
            guard.save.accepted?
          end
        end
      end
    end
    Timeout.timeout(15) { 2.times { ready.pop } }
    2.times { start << true }
    results = Timeout.timeout(15) { threads.map(&:value) }
    assert_equal 1, results.count(true)
    assert_equal 1, results.count(false)
    assert_equal 1, tenant.contact_requests.count
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
    threads&.each(&:join)
    if tenant
      ContactRequest.where(tenant_id: tenant.id).delete_all
      tenant.destroy!
    end
  end
end
