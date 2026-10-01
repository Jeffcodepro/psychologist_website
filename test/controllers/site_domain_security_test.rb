require "test_helper"

class SiteDomainSecurityTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @rose = Tenant.create!(name: "Rosemary", slug: "rosemary-domains", domain: "rosemary.example", primary: true)
    @thiago = Tenant.create!(name: "Thiago", slug: "thiago-domains", domain: "thiago.example")
    [@rose, @thiago].each do |tenant|
      tenant.create_site_setting!(professional_name: tenant.name)
      home = tenant.pages.create!(name: tenant.name, slug: "home", published: true)
      home.sections.create!(section_type: "text", publication_state: "published", title: "Exclusivo #{tenant.name}")
    end
    @user = @rose.users.create!(email: "rose-domain@example.test", password: "Domain-password-123!", admin: true)
    @login = @rose.rotate_admin_link!
    @key = @login.split('/').last
  end

  test "each customer domain serves its own site and cannot select another via slug" do
    host! @rose.domain
    get '/'
    assert_response :success
    assert_includes response.body, 'Exclusivo Rosemary'
    assert_not_includes response.body, 'Exclusivo Thiago'
    get root_path(site_slug: @thiago.slug)
    assert_response :not_found
    host! @thiago.domain
    get '/'
    assert_includes response.body, 'Exclusivo Thiago'
    assert_not_includes response.body, 'Exclusivo Rosemary'
    get sitemap_path(site_slug: @rose.slug)
    assert_response :not_found
    host! 'unregistered.example'
    get root_path(site_slug: @rose.slug)
    assert_response :not_found
  end

  test "a private login key is only valid on its own customer domain" do
    host! @thiago.domain
    get @login
    assert_response :not_found
    post @login, params: { user: { email: @user.email, password: 'Domain-password-123!' } }
    assert_response :not_found
    host! "www.#{@rose.domain}"
    get @login
    assert_response :success
    host! @rose.domain
    post @login, params: { user: { email: @user.email, password: 'Domain-password-123!' } }
    assert_response :redirect
    get '/admin'
    assert_response :success
  end

  test "an authenticated session cannot operate a different customer domain" do
    sign_in @user
    host! @thiago.domain
    get '/admin'
    assert_response :not_found
    assert_no_difference '@rose.pages.count' do
      post admin_pages_path, params: { page: { name: 'Unexpected' } }
      assert_response :not_found
    end
  end

  test "password recovery belongs to the customer domain and email links use that domain" do
    host! @thiago.domain
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      post user_password_path, params: { access_key: @key, user: { email: @user.email } }
      assert_response :not_found
    end
    host! @rose.domain
    token = @user.send_reset_password_instructions
    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.body.decoded, "http://rosemary.example/admin/password/edit?reset_password_token="
    assert_includes mail.body.decoded, 'painel de Rosemary'
    host! @thiago.domain
    get edit_user_password_path(reset_password_token: token)
    assert_response :not_found
    patch user_password_path, params: { user: { reset_password_token: token, password: 'New-domain-password-123!', password_confirmation: 'New-domain-password-123!' } }
    assert_response :not_found
    assert @user.reload.valid_password?('Domain-password-123!')
    host! @rose.domain
    patch user_password_path, params: { user: { reset_password_token: token, password: 'New-domain-password-123!', password_confirmation: 'New-domain-password-123!' } }
    assert_response :redirect
    assert @user.reload.valid_password?('New-domain-password-123!')
  end

  test "public text is escaped or sanitized and SQL fragments cannot bypass page lookup" do
    home = @rose.pages.find_by!(slug: 'home')
    home.sections.first.update!(title: '<img src=x onerror=alert(1)>', body: '<script>alert(2)</script><a href="javascript:alert(3)">Texto</a>')
    host! @rose.domain
    get '/'
    assert_response :success
    assert_select '[onerror], a[href^="javascript:"], script:not([type="importmap"]):not([type="module"]):not([type="application/ld+json"]):not([src])', count: 0
    get '/home%27%20OR%201%3D1--'
    assert_includes [400, 404], response.status
    assert_no_difference 'Page.count' do
      get '/%3BDROP%20TABLE%20pages'
      assert_includes [400, 404], response.status
    end
    get '/'
    assert_includes response.headers['X-Content-Type-Options'], 'nosniff'
  end
end
