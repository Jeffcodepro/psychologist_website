require "test_helper"

class TenantSecurityTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Cliente A", slug: "cliente-a", primary: true)
    @other = Tenant.create!(name: "Cliente B", slug: "cliente-b", domain: "client-b.example.com")
    @user = @tenant.users.create!(email: "owner@example.test", password: "Strong-password-123!", admin: true)
    @other_user = @other.users.create!(email: "other@example.test", password: "Other-password-123!", admin: true)
    @page = TenantProvisioner.ensure_contact_page!(@tenant)
    @other_page = TenantProvisioner.ensure_contact_page!(@other)
    @section = @page.sections.draft.first
    @other_section = @other_page.sections.draft.first
    @path = @tenant.rotate_admin_link!
    @key = @path.split("/").last
  end

  test "only private entry admits a provisioned administrator and passwords are hashed" do
    get "/admin"
    assert_response :not_found
    %w[/admin/login /users/sign_in /users/sign_up /admin/access/invalid].each do |path|
      get path
      assert_response :not_found
    end
    assert_no_difference "User.count" do
      post "/users", params: { user: { email: "attack@example.test", password: "password", admin: true } }
    end
    assert_response :not_found
    get @path
    assert_response :success
    assert_select '.auth-eyebrow', text: /Cliente A/
    post @path, params: { user: { email: @user.email, password: "Strong-password-123!", tenant_id: @other.id } }
    assert_redirected_to admin_root_path
    get admin_root_path
    assert_response :success
    assert @user.encrypted_password.start_with?("$2a$", "$2b$")
    assert_not_equal "Strong-password-123!", @user.encrypted_password
  end

  test "private link rotation revokes old entry" do
    @tenant.rotate_admin_link!
    get @path
    assert_response :not_found
  end

  test "an expired session returns to the private login and allows the editor to be reopened" do
    get @path
    post @path, params: { user: { email: @user.email, password: "Strong-password-123!" } }
    get admin_page_preview_path(@page)
    assert_response :success

    travel User.timeout_in + 1.minute do
      get admin_page_preview_path(@page)
      assert_redirected_to new_user_session_path(access_key: @key)
      follow_redirect!
      assert_response :success
      assert_select '.auth-eyebrow', text: /Cliente A/
      assert_includes response.body, "Sua sessão expirou"
      get admin_root_path
      assert_redirected_to new_user_session_path(access_key: @key, locale: "pt-BR")
      post @path, params: { user: { email: @user.email, password: "Strong-password-123!" } }
      assert_redirected_to admin_root_path
      get admin_page_preview_path(@page)
      assert_response :success
    end
  end

  test "signing out removes authentication while preserving the private entry" do
    get @path
    post @path, params: { user: { email: @user.email, password: "Strong-password-123!" } }
    delete destroy_user_session_path
    assert_redirected_to new_user_session_path(access_key: @key)
    get admin_pages_path
    assert_redirected_to new_user_session_path(access_key: @key, locale: "pt-BR")
  end

  test "an expired session cannot recover a revoked private entry" do
    get @path
    post @path, params: { user: { email: @user.email, password: "Strong-password-123!" } }
    @tenant.rotate_admin_link!
    travel User.timeout_in + 1.minute do
      get admin_page_preview_path(@page)
      assert_redirected_to "/404.html"
    end
    get @path
    assert_response :not_found
  end

  test "non-administrators and suspended tenants cannot enter the CMS" do
    @user.update!(admin: false)
    get @path
    post @path, params: { user: { email: @user.email, password: 'Strong-password-123!' } }
    get admin_root_path
    assert_response :redirect
    @user.update!(admin: true)
    sign_in @user
    @tenant.update!(active: false)
    get admin_root_path
    assert_redirected_to '/404.html'
    sign_out @user
    get @path
    assert_response :not_found
    get contact_path(site_slug: @tenant.slug)
    assert_response :not_found
  end

  test "another client's login and public registration cannot grant access" do
    get @path
    post @path, params: { user: { email: @other_user.email, password: "Other-password-123!" } }
    get admin_root_path
    assert_response :redirect
    assert_redirected_to new_user_session_path(access_key: @key, locale: 'pt-BR')
  end

  test "all CMS lookups reject foreign pages, sections, cards, slides and messages" do
    sign_in @user
    other_card = @other_section.section_items.create!(title: "Privado B")
    message = @other.contact_requests.create!(full_name: "Pessoa B", email: "b@example.test", phone: "11999991234", message: "Mensagem privada")
    [admin_page_preview_frame_path(@other_page), edit_admin_page_path(@other_page), admin_page_sections_path(@other_page),
     edit_admin_page_section_path(@page, @other_section), edit_admin_page_section_section_item_path(@page, @section, other_card), admin_contact_request_path(message)].each do |path|
      get path
      assert_response :not_found, path
    end
    assert_no_difference "Page.count" do
      delete admin_page_path(@other_page)
      assert_response :not_found
    end
    patch swap_fields_admin_page_sections_path(@page), params: { source_id: @section.id, target_id: @other_section.id, field: "title" }
    assert_response :not_found
    post admin_page_publication_path(@other_page)
    assert_response :not_found
    post deliver_admin_contact_request_path(message)
    assert_response :not_found
    slide = @other_section.section_slides.build(role: 'image', position: 0)
    slide.image.attach(io: StringIO.new('image'), filename: 'foreign.png', content_type: 'image/png')
    slide.save!
    patch admin_page_section_path(@page, @section), params: { section: { section_slides_attributes: { '0' => { id: slide.id, _destroy: '1' } } } }
    assert_response :not_found
    assert SectionSlide.exists?(slide.id)
    get admin_contact_requests_path
    assert_not_includes response.body, "Pessoa B"
    get admin_pages_path
    assert_select "a[href*='/admin/pages/#{@other_page.id}/']", count: 0
    post admin_pages_path, params: { page: { name: "Nova página", tenant_id: @other.id } }
    assert_equal @tenant.id, Page.find_by!(slug: "nova-pagina").tenant_id
  end

  test "public routes select domain or slug and never expose admin links" do
    @other_section.update!(title: "Exclusivo do cliente B")
    PagePublicationService.new(page: @other_page).call
    get contact_path(site_slug: @other.slug)
    assert_response :success
    assert_includes response.body, "Exclusivo do cliente B"
    assert_select 'a[href*="/admin"], a[href*="/users/"]', count: 0
    assert_select "form[action*='/s/#{@other.slug}/contato']"
    host! "client-b.example.com"
    get contact_path
    assert_response :success
    assert_includes response.body, "Exclusivo do cliente B"
    host! "unknown.example.com"
    get contact_path
    assert_response :not_found
  end

  test "signed in navigation and contact stay in CMS and preserve English" do
    sign_in @user
    get contact_path
    assert_redirected_to admin_root_path(locale: "pt-BR")
    get admin_page_preview_frame_path(@page, locale: "en")
    assert_response :success
    assert_select "a[href*='/admin/pages/#{@page.id}/preview'][href*='locale=en']"
    assert_select 'a[href^="/contato"], a[href="/"]', count: 0
    get admin_page_preview_path(@page)
    assert_response :success
    assert_select 'iframe[src*="locale=en"]'
    get edit_admin_page_section_path(@page, @section)
    assert_select 'a[href*="locale=en"]'
    post admin_page_section_section_items_path(@page, @section), params: { from_preview: "1", section_item: { title: "Card novo" } }
    assert_redirected_to admin_page_preview_path(@page, locale: "en")
  end

  test "bad upload bytes and cross-client signed blobs are rejected" do
    sign_in @user
    file = Tempfile.new(['invalid', '.png'])
    file.write('<script>alert(1)</script>'); file.rewind
    upload = Rack::Test::UploadedFile.new(file.path, 'image/png')
    patch admin_page_section_path(@page, @section), params: { section: { image: upload } }
    assert_response :unprocessable_entity
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('image'), filename: 'foreign.png', content_type: 'image/png')
    patch admin_page_section_path(@page, @section), params: { section: { image: blob.signed_id } }
    assert_response :unprocessable_entity
    assert_not @section.reload.image.attached?
  ensure
    file&.close!
  end

  test "private files and unused direct upload endpoints are inaccessible" do
    %w[/.env /.git/config /config/master.key].each do |path|
      get path
      assert_includes [403, 404], response.status
    end
    post '/rails/active_storage/direct_uploads', params: { blob: { filename: 'x' } }
    assert_response :forbidden
  end

  test "CSRF protection rejects a forged mutation even with an admin session" do
    sign_in @user
    old = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    patch admin_page_section_path(@page, @section), params: { section: { title: "Ataque" } }
    assert_response :unprocessable_entity
    assert_not_equal "Ataque", @section.reload.title
  ensure
    ActionController::Base.allow_forgery_protection = old
  end

  test "wrong passwords lock an account and repeated authentication is throttled" do
    get @path
    6.times { post @path, params: { user: { email: @user.email, password: 'wrong' } } }
    assert @user.reload.access_locked?
    15.times { post @path, params: { user: { email: 'unknown@example.test', password: 'wrong' } } }
    assert_response :too_many_requests
    assert_equal '900', response.headers['Retry-After']
  end

  test "password recovery is tenant-scoped and uses a single-use hashed token" do
    get @path
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      post user_password_path, params: { access_key: @key, user: { email: @other_user.email, tenant_id: @other.id } }
    end
    assert_nil @other_user.reload.reset_password_token
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      post user_password_path, params: { access_key: @key, user: { email: @user.email } }
    end
    assert @user.reload.reset_password_token.present?
    token = @user.send_reset_password_instructions
    assert_not_equal token, @user.reload.reset_password_token
    patch user_password_path, params: { user: { reset_password_token: token, password: 'A-new-password-123!', password_confirmation: 'A-new-password-123!' } }
    assert @user.reload.valid_password?('A-new-password-123!')
    assert_nil @user.reset_password_token
  end
end
