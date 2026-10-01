require "test_helper"
require "minitest/mock"
require "active_storage/service/cloudinary_service"
require "base64"

class CloudinaryDeliveryTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @previous = { cloud_name: Cloudinary.config.cloud_name, api_key: Cloudinary.config.api_key, api_secret: Cloudinary.config.api_secret }
    Cloudinary.config(cloud_name: "rosemary-test", api_key: "12345", api_secret: "test-only-secret", secure: true)
    tenant = Tenant.create!(name: "CDN", slug: "cdn", primary: true)
    @setting = tenant.create_site_setting!(professional_name: "CDN")
    bytes = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=")
    @setting.logo.attach(io: StringIO.new(bytes), filename: 'logo.png', content_type: 'image/png')
    @blob = @setting.logo.blob
    @page = tenant.pages.create!(name: 'Home', slug: 'home')
    @section = @page.sections.create!(section_type: 'hero', title: 'Apresentação')
    @section.image.attach(@blob)
  end

  teardown { Cloudinary.config(**@previous) }

  test "cloud images use signed CDN transforms and do not enqueue local variants" do
    @blob.update!(service_name: 'cloudinary')
    clear_enqueued_jobs
    assert_no_enqueued_jobs only: ActiveStorage::TransformJob do
      PagePublicationService.new(page: @page).call
      @setting.profile_image.attach(@blob)
    end
    assert_no_difference 'ActiveStorage::VariantRecord.count' do
      get root_path
    end
    assert_response :success
    logo = Nokogiri::HTML(response.body).at_css('img.site-navbar__logo')
    assert logo['src'].start_with?('https://res.cloudinary.com/rosemary-test/image/upload/s--')
    assert_includes logo['src'], 'c_limit'
    assert_includes logo['src'], 'w_256'
    assert_includes logo['src'], 'q_auto:good'
    assert_includes logo['src'], 'f_auto'
    assert_includes logo['srcset'], '512w'
    assert_equal 'high', logo['fetchpriority']
    assert_not_includes response.body, 'test-only-secret'
    assert_includes response.headers['Content-Security-Policy'], 'https://res.cloudinary.com'
    assert_not_includes response.headers['Content-Security-Policy'], 'api.cloudinary.com'
  end

  test "publishing existing disk images does not repeat preprocessing" do
    clear_enqueued_jobs
    assert_no_enqueued_jobs only: ActiveStorage::TransformJob do
      2.times { PagePublicationService.new(page: @page).call }
    end
  end

  test "official adapter uploads original files with their checksum and no incoming transform" do
    @blob.update!(service_name: 'cloudinary')
    captured = nil
    uploader = ->(file, **options) { captured = options; assert_equal @blob.byte_size, file.size; {} }
    # Fetch the original from the disk service, not the fake Cloudinary destination.
    disk = ActiveStorage::Blob.services.fetch('test')
    disk.open(@blob.key, checksum: @blob.checksum, verify: true) do |file|
      Cloudinary::Uploader.stub(:upload_large, uploader) do
        @blob.service.upload(@blob.key, file, checksum: @blob.checksum, content_type: @blob.content_type)
      end
    end
    assert_equal @blob.key.to_s, captured[:public_id].to_s
    assert_equal @blob.checksum, captured[:context][:checksum]
    assert_nil captured[:transformation]
    assert_nil captured[:upload_preset]
  end
end
