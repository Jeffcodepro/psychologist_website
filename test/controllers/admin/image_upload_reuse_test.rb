require "test_helper"
require "minitest/mock"
require "vips"
require "active_storage/service/cloudinary_service"

class Admin::ImageUploadReuseTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @tenant = Tenant.create!(name: "Imagens únicas", slug: "reuse-images", primary: true)
    @settings = @tenant.create_site_setting!(professional_name: "Imagens únicas")
    sign_in @tenant.users.create!(admin: true, email: "reuse@example.test", password: "Reuse-test-password-123!")
    @page = @tenant.pages.create!(name: "Imagens", slug: "imagens")
    @section = @page.sections.create!(section_type: "hero", title: "Apresentação")
    @bytes = Vips::Image.black(12, 10).new_from_image([30, 80, 50]).write_to_buffer(".png")
    @different = Vips::Image.black(12, 10).new_from_image([80, 40, 60]).write_to_buffer(".png")
    @files = []
    @previous_service = ActiveStorage::Blob.service
    @previous_config = { cloud_name: Cloudinary.config.cloud_name, api_key: Cloudinary.config.api_key, api_secret: Cloudinary.config.api_secret }
    Cloudinary.config(cloud_name: "upload-reuse-test", api_key: "12345", api_secret: "test-only-secret", secure: true)
    ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch("cloudinary")
    clear_enqueued_jobs
  end

  teardown do
    ActiveStorage::Blob.service = @previous_service
    Cloudinary.config(**@previous_config)
    @files.each(&:close!)
  end

  test "repeated saves and publications perform one original upload and keep its key" do
    with_cloudinary_calls do |uploads, deletes|
      patch admin_page_section_path(@page, @section), params: { section: { image: upload } }
      assert_response :redirect
      blob = @section.reload.image.blob
      assert_equal 1, uploads.size
      assert_no_difference "ActiveStorage::Blob.count" do
        3.times do |index|
          patch admin_page_section_path(@page, @section), params: { section: { title: "Abertura #{index}", image_zoom: 0.8 } }
          assert_response :redirect
          post admin_page_publication_path(@page)
          assert_response :redirect
          perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
          assert_equal blob.id, @page.sections.published.first.image.blob_id
          assert_equal blob.key, @section.reload.image.blob.key
        end
      end
      assert_equal 1, uploads.size
      assert_empty deletes
    end
  end

  test "selecting identical bytes again even renamed reuses the original across the same site" do
    with_cloudinary_calls do |uploads, _|
      patch admin_page_section_path(@page, @section), params: { section: { image: upload } }
      original = @section.reload.image.blob
      assert_no_difference "ActiveStorage::Blob.count" do
        patch admin_page_section_path(@page, @section), params: { section: { image: upload("renamed-photo.png"), image_zoom: 0.5 } }
        assert_response :redirect
        patch admin_site_setting_path, params: { site_setting: { logo: upload("logo.png"), profile_image: upload("profile.png") } }
        assert_response :redirect
        post admin_page_section_section_items_path(@page, @section), params: { section_item: { item_kind: "card", title: "Card", image: upload("card.png") } }
        assert_response :redirect
      end
      assert_equal 1, uploads.size
      assert_equal original.id, @section.reload.image.blob_id
      assert_equal original.id, @settings.reload.logo.blob_id
      assert_equal original.id, @settings.profile_image.blob_id
      assert_equal original.id, @section.section_items.last.image.blob_id
    end
  end

  test "a first multipart upload shared by a photo banner and slides sends the original once" do
    with_cloudinary_calls do |uploads, _|
      assert_difference "ActiveStorage::Blob.count", 1 do
        patch admin_page_section_path(@page, @section), params: { section: {
          image: upload, banner: upload("banner.png"), section_slides_attributes: {
            "0" => { role: "image", image: upload("slide.png") },
            "1" => { role: "banner", image: upload("other-banner.png") }
          }
        } }
        assert_response :redirect
      end
      @section.reload
      assert_equal 1, uploads.size
      ids = [@section.image.blob_id, @section.banner.blob_id] + @section.section_slides.map { |slide| slide.image.blob_id }
      assert_equal 1, ids.uniq.size
    end
  end

  test "a changed image uploads once and the previous public original survives until republishing" do
    with_cloudinary_calls do |uploads, deletes|
      patch admin_page_section_path(@page, @section), params: { section: { image: upload } }
      original = @section.reload.image.blob
      PagePublicationService.new(page: @page).call
      patch admin_page_section_path(@page, @section), params: { section: { image: upload(bytes: @different) } }
      assert_response :redirect
      replacement = @section.reload.image.blob
      assert_not_equal original.id, replacement.id
      perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
      assert_equal original.id, @page.sections.published.first.image.blob_id
      assert ActiveStorage::Blob.exists?(original.id)
      assert_empty deletes
      PagePublicationService.new(page: @page).call
      perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
      assert_not ActiveStorage::Blob.exists?(original.id)
      assert_equal [original.key.to_s], deletes
      assert ActiveStorage::Blob.exists?(replacement.id)
      assert_equal 2, uploads.size
    end
  end

  test "removing an unused draft image schedules disposal instead of leaving an orphan" do
    with_cloudinary_calls do |_, deletes|
      patch admin_page_section_path(@page, @section), params: { section: { image: upload } }
      original = @section.reload.image.blob
      patch admin_page_section_path(@page, @section), params: { section: { remove_image: "1" } }
      assert_response :redirect
      assert_not @section.reload.image.attached?
      perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
      assert_not ActiveStorage::Blob.exists?(original.id)
      assert_equal [original.key.to_s], deletes
    end
  end

  test "a removed card image remains available until its last published reference disappears" do
    with_cloudinary_calls do |_, deletes|
      post admin_page_section_section_items_path(@page, @section), params: { section_item: { title: "Card", image: upload } }
      card = @section.section_items.last
      original = card.image.blob
      PagePublicationService.new(page: @page).call
      patch admin_page_section_section_item_path(@page, @section, card), params: { section_item: { remove_image: "1" } }
      assert_response :redirect
      perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
      assert_not card.reload.image.attached?
      assert ActiveStorage::Blob.exists?(original.id)
      assert_empty deletes
      PagePublicationService.new(page: @page).call
      perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
      assert_not ActiveStorage::Blob.exists?(original.id)
      assert_equal [original.key.to_s], deletes
    end
  end

  test "invalid changes never upload a file and removal wins over a newly selected file" do
    with_cloudinary_calls do |uploads, _|
      assert_no_difference "ActiveStorage::Blob.count" do
        patch admin_page_section_path(@page, @section), params: { section: { image: upload, image_zoom: 9 } }
        assert_response :unprocessable_entity
        patch admin_page_section_path(@page, @section), params: { section: { image: upload, remove_image: "1" } }
        assert_response :redirect
      end
      assert_empty uploads
      assert_not @section.reload.image.attached?
    end
  end

  test "matching files belonging to a different site are never reused" do
    with_cloudinary_calls do |uploads, _|
      another = Tenant.create!(name: "Outro site", slug: "other-images")
      settings = another.create_site_setting!(professional_name: "Outro site")
      settings.logo.attach(io: StringIO.new(@bytes), filename: "same.png", content_type: "image/png")
      patch admin_page_section_path(@page, @section), params: { section: { image: upload } }
      assert_response :redirect
      assert_not_equal settings.logo.blob_id, @section.reload.image.blob_id
      assert_equal 2, uploads.size
      assert_nil ImageUploadReuse::Context.tenant_id
    end
  end

  test "reselecting a file recovers a database reference whose remote original is missing" do
    with_cloudinary_calls do |uploads, _|
      patch admin_page_section_path(@page, @section), params: { section: { image: upload } }
      missing = @section.reload.image.blob
      uploads.clear # Simulate an interrupted remote upload without deleting the DB reference.
      patch admin_page_section_path(@page, @section), params: { section: { image: upload } }
      assert_response :redirect
      assert_equal 1, uploads.size
      assert_not_equal missing.id, @section.reload.image.blob_id
    end
  end

  test "unavailable storage verification keeps the original and shows validation instead of duplicating" do
    with_cloudinary_calls do |uploads, _|
      patch admin_page_section_path(@page, @section), params: { section: { image: upload } }
      original_id = @section.reload.image.blob_id
      unavailable = ->(*) { raise IOError, "test-only unavailable" }
      ActiveStorage::Blob.service.stub(:exist?, unavailable) do
        assert_no_difference "ActiveStorage::Blob.count" do
          patch admin_page_section_path(@page, @section), params: { section: { image: upload } }
          assert_response :unprocessable_entity
        end
      end
      assert_equal original_id, @section.reload.image.blob_id
      assert_equal 1, uploads.size
    end
  end

  test "clear image action also schedules cleanup after the last use" do
    with_cloudinary_calls do |_, deletes|
      patch admin_page_section_path(@page, @section), params: { section: { banner: upload } }
      original = @section.reload.banner.blob
      patch clear_field_admin_page_section_path(@page, @section), params: { field: "banner" }
      assert_response :redirect
      perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
      assert_equal [original.key.to_s], deletes
      assert_not @section.reload.banner.attached?
    end
  end

  private

  def upload(filename = "photo.png", bytes: @bytes)
    file = Tempfile.new(["upload-reuse", ".png"])
    file.binmode
    file.write(bytes)
    file.rewind
    @files << file
    Rack::Test::UploadedFile.new(file.path, "image/png", original_filename: filename)
  end

  def with_cloudinary_calls
    uploads, deletes = [], []
    uploader = ->(io, **options) { uploads << options.fetch(:public_id).to_s; assert_operator io.size, :>, 0; {} }
    destroyer = ->(key, **_) { deletes << key.to_s; { "result" => "ok" } }
    resource = ->(key, **) do
      raise Cloudinary::Api::NotFound, "test-only missing image" unless uploads.include?(key.to_s) && !deletes.include?(key.to_s)
      {}
    end
    Cloudinary::Uploader.stub(:upload_large, uploader) do
      Cloudinary::Uploader.stub(:destroy, destroyer) do
        Cloudinary::Api.stub(:resource, resource) { yield uploads, deletes }
      end
    end
  end
end
