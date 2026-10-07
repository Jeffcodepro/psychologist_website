require "test_helper"
require "minitest/mock"
require "active_storage/service/cloudinary_service"

class Admin::VideoMediaTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper
  VIDEO_ID = "M7lc1UVf-VE"

  setup do
    @tenant = Tenant.create!(name: "Vídeos", slug: "video-tests", primary: true)
    @tenant.create_site_setting!(professional_name: "Vídeos")
    @user = @tenant.users.create!(admin: true, email: "video@example.test", password: "Video-test-password-123!")
    sign_in @user
    @page = @tenant.pages.create!(name: "Mídias", slug: "midias")
    @section = @page.sections.create!(section_type: "cards", title: "Vídeos", cards_wrap: false)
    @files = []
  end
  teardown { @files.each(&:close!) }

  test "youtube links accept normal short shorts live and embed links but reject other hosts and markup" do
    ["https://youtu.be/#{VIDEO_ID}?si=test", "https://www.youtube.com/watch?v=#{VIDEO_ID}&t=3", "https://m.youtube.com/shorts/#{VIDEO_ID}", "https://www.youtube.com/live/#{VIDEO_ID}", "https://www.youtube-nocookie.com/embed/#{VIDEO_ID}"].each do |url|
      assert_equal VIDEO_ID, YoutubeVideo.id(url)
    end
    ["javascript:alert(1)", "https://youtube.com.evil.test/watch?v=#{VIDEO_ID}", "https://youtube.com@evil.test/watch?v=#{VIDEO_ID}", "https://www.youtube.com:444/watch?v=#{VIDEO_ID}", "<iframe src='https://youtube.com'></iframe>", "https://youtu.be/short", "https://vimeo.com/#{VIDEO_ID}"].each { |url| assert_nil YoutubeVideo.id(url) }
  end

  test "youtube in section banner card and mixed slides publishes without uploading files" do
    assert_no_difference "ActiveStorage::Blob.count" do
      patch admin_page_section_path(@page, @section), params: { section: {
        video_settings: { image: youtube, banner: youtube },
        section_slides_attributes: { "0" => { role: "image", video_settings: { image: youtube } } }
      } }
      assert_response :redirect
      post admin_page_section_section_items_path(@page, @section), params: { section_item: { title: "Um vídeo", video_settings: { image: youtube } } }
      assert_response :redirect
      2.times { post admin_page_publication_path(@page); assert_response :redirect }
    end
    get edit_admin_page_section_path(@page, @section)
    assert_response :success
    assert_equal 1, @section.reload.section_slides.count
    sign_out @user
    get public_page_path(slug: @page.slug)
    assert_response :success
    assert_select '.cms-video[data-video-player-youtube-value=?]', VIDEO_ID, count: 4
    assert_select '.media-sequence[data-media-sequence-manual-value=true]', count: 2
    assert_select '.cms-video img[src=?]', "https://i.ytimg.com/vi/#{VIDEO_ID}/hqdefault.jpg", count: 4
    assert_select 'iframe', count: 0
    assert_includes response.headers['Content-Security-Policy'], 'https://www.youtube-nocookie.com'
  end

  test "invalid youtube links and remote upload URLs return validation errors without a server error" do
    patch admin_page_section_path(@page, @section), params: { section: { video_settings: { image: { source: "youtube", youtube_url: "https://evil.test/watch?v=#{VIDEO_ID}" } } } }
    assert_response :unprocessable_entity
    assert_not @section.reload.video_source?
    patch admin_page_section_path(@page, @section), params: { section: { video: "https://evil.test/video.mp4", video_settings: { image: { source: "upload" } } } }
    assert_response :unprocessable_entity
    assert_not @section.reload.video.attached?
  end

  test "video adjustments and card collection settings are independent for each screen" do
    patch admin_page_section_path(@page, @section), params: { section: {
      cards_orientation: "horizontal", cards_wrap: false,
      video_settings: { image: youtube.merge(fit: "cover", zoom: "1.8", tablet: { zoom: "0.8", fit: "contain" }, mobile: { zoom: "0.4", x: "20" }) },
      responsive_settings: { tablet: { cards_orientation: "vertical", cards_alignment: "left" }, mobile: { cards_orientation: "horizontal", cards_wrap: "true", cards_autoplay: "false", cards_placement: "before" } }
    } }
    assert_response :redirect
    @section.reload
    assert_equal "1.8", @section.video_value("image", "zoom")
    assert_equal "0.8", @section.video_value("image", "zoom", "tablet")
    assert_equal "0.4", @section.video_value("image", "zoom", "mobile")
    assert @section.cards_carousel?
    assert_not @section.cards_carousel?("tablet")
    assert_not @section.cards_carousel?("mobile")
    assert_equal "vertical", @section.cards_device_config("tablet")[:orientation]
    assert_equal "before", @section.visual_value("cards_placement", "mobile")
    patch admin_page_section_path(@page, @section), params: { section: { responsive_settings: { mobile: { cards_wrap: "false" } } } }
    assert_response :redirect
    assert_equal "vertical", @section.reload.cards_device_config("tablet")[:orientation]
    assert @section.cards_carousel?("mobile")
  end

  test "local video reupload across slots and repeated publication uses one original" do
    assert_difference "ActiveStorage::Blob.count", 1 do
      patch admin_page_section_path(@page, @section), params: { section: { video: upload, banner_video: upload,
        video_settings: { image: { source: "upload" }, banner: { source: "upload" } },
        section_slides_attributes: { "0" => { role: "image", video: upload, video_settings: { image: { source: "upload" } } } }
      } }
      assert_response :redirect
      original = @section.reload.video.blob
      assert_equal "video/mp4", original.content_type
      assert_equal original.id, @section.banner_video.blob_id
      assert_equal original.id, @section.section_slides.first.video.blob_id
      post admin_page_section_section_items_path(@page, @section), params: { section_item: { title: "Vídeo", video: upload, video_settings: { image: { source: "upload" } } } }
      assert_response :redirect
      2.times { post admin_page_publication_path(@page); assert_response :redirect }
      assert_equal original.id, @page.sections.published.first.video.blob_id
      assert_equal original.id, @page.sections.published.first.section_items.first.video.blob_id
      perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
      assert ActiveStorage::Blob.exists?(original.id)
    end
  end

  test "cloudinary receives resource type video once for repeated bytes" do
    previous = ActiveStorage::Blob.service
    previous_config = { cloud_name: Cloudinary.config.cloud_name, api_key: Cloudinary.config.api_key, api_secret: Cloudinary.config.api_secret }
    Cloudinary.config(cloud_name: "video-test", api_key: "123", api_secret: "test-only")
    ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch("cloudinary")
    uploads = []
    uploader = ->(_io, **options) { uploads << options; {} }
    Cloudinary::Uploader.stub(:upload_large, uploader) do
      Cloudinary::Api.stub(:resource, {}) do
        2.times do
          patch admin_page_section_path(@page, @section), params: { section: { video: upload, video_settings: { image: { source: "upload" } } } }
          assert_response :redirect
          post admin_page_publication_path(@page)
          assert_response :redirect
        end
      end
    end
    assert_equal 1, uploads.size
    assert_equal "video", uploads.first[:resource_type]
    url = @section.reload.video.blob.url
    assert_includes url, "/video/upload/"
  ensure
    ActiveStorage::Blob.service = previous
    Cloudinary.config(**previous_config)
  end

  test "moving video between sections and clearing preserves public version until publication" do
    other = @page.sections.create!(section_type: "text", title: "Outro")
    patch admin_page_section_path(@page, @section), params: { section: { video: upload, video_settings: { image: { source: "upload" } } } }
    original = @section.reload.video.blob
    PagePublicationService.new(page: @page).call
    patch swap_fields_admin_page_sections_path(@page), params: { source_id: @section.id, target_id: other.id, field: "image" }, as: :json
    assert_response :no_content
    assert other.reload.video_available?
    assert_not @section.reload.video.attached?
    assert_equal original.id, other.video.blob_id
    patch clear_field_admin_page_section_path(@page, other), params: { field: "image" }
    assert_response :redirect
    perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
    assert ActiveStorage::Blob.exists?(original.id)
    PagePublicationService.new(page: @page).call
    perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
    assert_not ActiveStorage::Blob.exists?(original.id)
  end

  private
  def youtube
    { source: "youtube", youtube_url: "https://youtu.be/#{VIDEO_ID}" }
  end
  def upload
    file = Tempfile.new(["video-test", ".mp4"])
    file.binmode
    file.write([24].pack("N") + "ftypmp42" + [0].pack("N") + "mp42isom")
    file.rewind
    @files << file
    Rack::Test::UploadedFile.new(file.path, "video/mp4", original_filename: "video.mp4")
  end
end
