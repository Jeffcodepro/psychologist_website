require "test_helper"
require "vips"

class FaviconsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Ícone", slug: "icone", primary: true)
    @settings = @tenant.create_site_setting!(professional_name: "Ícone")
    attach_logo(@settings)
    @page = @tenant.pages.create!(name: "Home", slug: "home")
    PagePublicationService.new(page: @page).call
  end

  test "public favicon is a cached square PNG and does not require authentication" do
    get root_path
    assert_select 'link[rel="icon"][href="/favicon.png"][sizes="192x192"]'
    get site_favicon_path
    assert_response :success
    assert_equal 'image/png', response.media_type
    icon = Vips::Image.new_from_buffer(response.body, '')
    assert_equal [192, 192], [icon.width, icon.height]
    assert_includes response.headers['Cache-Control'], 'public'
    etag = response.headers['ETag']
    assert_no_difference 'ActiveStorage::VariantRecord.count' do
      get site_favicon_path
      assert_response :success
    end
    get site_favicon_path, headers: { 'If-None-Match' => etag }
    assert_response :not_modified
    attach_logo(@settings, 'same-content-renamed.png')
    get site_favicon_path, headers: { 'If-None-Match' => etag }
    assert_response :not_modified
    attach_logo(@settings, 'replacement.png', color: [80, 40, 110, 255])
    get site_favicon_path, headers: { 'If-None-Match' => etag }
    assert_response :success
    assert_not_equal etag, response.headers['ETag']
  end

  test "logged in administrators can load their public icon without redirect" do
    sign_in @tenant.users.create!(admin: true, email: 'favicon@example.test', password: 'Favicon-test-password-123!')
    get admin_root_path
    assert_select 'link[rel="icon"][href="/favicon.png"]'
    get site_favicon_path
    assert_response :success
    assert_equal 'image/png', response.media_type
  end

  test "favicon is scoped to the requested site and handles missing logos" do
    other = Tenant.create!(name: 'Outro', slug: 'outro', domain: 'outro.example.test')
    other.create_site_setting!(professional_name: 'Outro')
    get site_favicon_path(site_slug: other.slug)
    assert_response :not_found
    host! other.domain
    get site_favicon_path
    assert_response :not_found
    get site_favicon_path(site_slug: @tenant.slug)
    assert_response :not_found
  end

  private

  def attach_logo(settings, filename = 'logo.png', color: [30, 90, 60, 255])
    image = Vips::Image.black(300, 180).new_from_image(color).cast(:uchar).write_to_buffer('.png')
    settings.logo.attach(io: StringIO.new(image), filename: filename, content_type: 'image/png')
  end
end
