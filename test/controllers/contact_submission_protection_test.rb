require "test_helper"
require "minitest/mock"

class ContactSubmissionProtectionTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create!(name: "Contato protegido", slug: "protected", primary: true)
    @tenant.create_site_setting!(professional_name: "Contato protegido")
    @page = TenantProvisioner.ensure_contact_page!(@tenant)
    @form = @page.sections.published.first
    @details = { full_name: "Visitante Teste", phone: "11999991234", email: "visitor@example.test", message: "Gostaria de conversar." }
  end

  def submit(details = @details, client: self, ip: "203.0.113.10", path: contact_requests_path, extra_headers: {})
    client.post path, params: { form_section_id: @form.id, contact_request: { answers: details } },
      headers: { "REMOTE_ADDR" => ip }.merge(extra_headers)
  end

  test "reload keeps confirmation and repeated posts do not retry a failed email" do
    calls = 0
    EmailDelivery.stub(:call, ->(_) { calls += 1; false }) do
      assert_difference "ContactRequest.count", 1 do
        submit
        assert_response :success
        get contact_path
        assert_response :success
        assert_select ".appointment-form__success", text: /Mensagem recebida/
        assert_select "form.appointment-form", count: 0
        submit
        assert_response :too_many_requests
        assert_includes 1..600, response.headers["Retry-After"].to_i
      end
    end
    assert_equal 1, calls
    assert_includes response.headers["Cache-Control"], "private"
  end

  test "a new browser and cleared middleware counters do not bypass the IP cooldown" do
    submit
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    visitor = open_session
    assert_no_difference "ContactRequest.count" do
      submit(@details.merge(email: "different@example.test"), client: visitor)
    end
    assert_equal 429, visitor.response.status
    assert_includes visitor.response.body, "Aguarde para enviar novamente"
    assert_not_includes visitor.response.body, @details[:email]
  end

  test "normalised email is limited even with a new IP and browser" do
    submit
    visitor = open_session
    assert_no_difference "ContactRequest.count" do
      submit(@details.merge(email: " VISITOR@EXAMPLE.TEST "), client: visitor, ip: "203.0.113.20")
    end
    assert_equal 429, visitor.response.status
  end

  test "same browser cannot bypass the cooldown by changing both IP and email" do
    submit
    assert_no_difference "ContactRequest.count" do
      submit(@details.merge(email: "changed@example.test"), ip: "203.0.113.20")
    end
    assert_response :too_many_requests
  end

  test "another visitor with a different email and IP remains able to submit" do
    submit
    visitor = open_session
    assert_difference "ContactRequest.count", 1 do
      submit(@details.merge(email: "different@example.test"), client: visitor, ip: "203.0.113.20")
    end
    assert_equal 200, visitor.response.status
  end

  test "receipt and database cooldown expire after ten minutes" do
    freeze_time do
      submit
      travel 10.minutes
      get contact_path
      assert_select "form.appointment-form", count: 1
      assert_difference "ContactRequest.count", 1 do
        submit
        assert_response :success
      end
    end
  end

  test "the fifth recent IP submission enforces the rolling hourly limit" do
    now = Time.current.change(usec: 0)
    freeze_time do
      [59, 48, 37, 26, 15].each do |minutes|
        @tenant.contact_requests.create!(@details.merge(created_at: now - minutes.minutes,
          request_fingerprint: ContactSubmissionGuard.fingerprint("203.0.113.10")))
      end
      assert_no_difference "ContactRequest.count" do
        submit(@details.merge(email: "new@example.test"))
        assert_response :too_many_requests
      end
      assert_includes 1..60, response.headers["Retry-After"].to_i
      travel 61.seconds
      assert_difference "ContactRequest.count", 1 do
        submit
        assert_response :success
      end
    end
  end

  test "invalid data can be corrected without consuming the submission cooldown" do
    submit(@details.merge(email: "invalid"))
    assert_response :unprocessable_entity
    assert_difference "ContactRequest.count", 1 do
      submit
      assert_response :success
    end
  end

  test "honeypot requests never save or send email and do not set a success receipt" do
    EmailDelivery.stub(:call, ->(_) { flunk "Spam must not send email" }) do
      assert_no_difference "ContactRequest.count" do
        post contact_requests_path, params: { form_section_id: @form.id,
          contact_request: { website: "spam.example", answers: @details } }
        assert_response :success
      end
    end
    get contact_path
    assert_select "form.appointment-form", count: 1
  end

  test "receipts and email limits do not leak between sites" do
    submit
    other = Tenant.create!(name: "Outro", slug: "other-contact")
    other.create_site_setting!(professional_name: "Outro")
    @form = TenantProvisioner.ensure_contact_page!(other).sections.published.first
    get contact_path(site_slug: other.slug)
    assert_select "form.appointment-form", count: 1
    assert_difference "ContactRequest.count", 1 do
      submit(path: contact_requests_path(site_slug: other.slug))
      assert_response :success
    end
    get contact_path
    assert_select "form.appointment-form", count: 0
  end

  test "rapid attempts including invalid forms are blocked before controller work" do
    freeze_time do
      5.times do
        submit(@details.merge(email: "invalid"))
        assert_response :unprocessable_entity
      end
      submit(@details.merge(email: "invalid"), extra_headers: { "Turbo-Frame" => "contact_form_#{@form.id}" })
      assert_response :too_many_requests
      assert_includes 1..10, response.headers["Retry-After"].to_i
      assert_select "turbo-frame#contact_form_#{@form.id} [role=alert]"
      assert_equal 0, @tenant.contact_requests.count
    end
  end

  test "format suffix and trailing slash share the same attempt limit" do
    freeze_time do
      ["/contato", "/contato.json", "/contato/", "/s/protected/contato", "/s/protected/contato.json"].each do |path|
        submit(@details.merge(email: "invalid"), path: path)
        assert_response :unprocessable_entity
      end
      submit(path: "/s/protected/contato.json")
      assert_response :too_many_requests
      assert_equal 0, @tenant.contact_requests.count
    end
  end

  test "ten minute attempt limit also rejects slower invalid submissions" do
    travel_to Time.current.beginning_of_hour + 1.minute do
      10.times do
        submit(@details.merge(email: "invalid"))
        assert_response :unprocessable_entity
        travel 11.seconds
      end
      submit
      assert_response :too_many_requests
      assert_includes 11..600, response.headers["Retry-After"].to_i
      assert_equal 0, @tenant.contact_requests.count
    end
  end

  test "contact still requires CSRF protection" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference "ContactRequest.count" do
      submit
      assert_response :unprocessable_entity
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
