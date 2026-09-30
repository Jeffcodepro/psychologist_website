require "test_helper"
require "vips"
require "rake"

class ImageDeliveryTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include Devise::Test::IntegrationHelpers

  setup do
    tenant = Tenant.create!(name: "Imagens", slug: "imagens", primary: true)
    @settings = tenant.create_site_setting!(professional_name: "Imagens")
    coordinates = Vips::Image.xyz(1600, 1000)
    x, y = coordinates[0], coordinates[1]
    @original = (x % 255).bandjoin(y % 255).bandjoin((x + y) % 255).cast(:uchar).bandjoin(200).write_to_buffer(".png")
    @settings.logo.attach(io: StringIO.new(@original), filename: "logo.png", content_type: "image/png")
    @page = tenant.pages.create!(name: "Home", slug: "home")
    @hero = @page.sections.create!(section_type: "hero", title: "Abertura", position: 1)
    @hero.image.attach(@settings.logo.blob)
    @hero.section_slides.create!(role: "image", position: 1, image: @settings.logo.blob)
    @section = @page.sections.create!(section_type: "cards", title: "Conteúdos", position: 2)
    @card = @section.section_items.create!(title: "Card", image: @settings.logo.blob)
    PagePublicationService.new(page: @page).call
    @user = tenant.users.create!(admin: true, email: "images@example.test", password: "Images-test-password-123!")
  end

  test "public images use responsive proxy derivatives and prioritize only visible opening media" do
    get root_path
    assert_response :success
    assert_select "img.site-navbar__logo[loading='eager'][fetchpriority='high'][decoding='async']" do |images|
      assert_includes images.first['src'], '/representations/proxy/'
      assert_match(/128w.*256w.*512w/, images.first['srcset'])
    end
    assert_select "img.site-footer__logo[loading='lazy']"
    assert_select ".media-sequence__slide.is-active img[loading='eager'][fetchpriority='high']", count: 1
    assert_select ".media-sequence__slide:not(.is-active) img[loading='lazy']", count: 1
    assert_select "img.compact-card__image[loading='lazy'][srcset]"
    assert_select "img[src*='/blobs/redirect/']", count: 0
  end

  test "a cold logo request creates a smaller transparent WebP and preserves the original" do
    get root_path
    logo = Nokogiri::HTML(response.body).at_css('img.site-navbar__logo')
    assert_equal 0, @settings.logo.blob.variant_records.count
    get logo['src']
    assert_response :success
    assert_equal 'image/webp', response.media_type
    assert_includes response.headers['Cache-Control'], 'public'
    assert_includes response.headers['Cache-Control'], 'max-age='
    optimized = Vips::Image.new_from_buffer(response.body, '')
    assert_equal 256, optimized.width
    assert_equal 160, optimized.height
    assert optimized.has_alpha?
    assert_operator response.body.bytesize, :<, @original.bytesize
    assert_equal @original, @settings.logo.blob.download
    assert_no_difference 'ActiveStorage::VariantRecord.count' do
      get logo['src']
      assert_response :success
    end
  end

  test "new uploads enqueue their display variants in the background" do
    clear_enqueued_jobs
    assert_enqueued_jobs 3, only: ActiveStorage::TransformJob do
      @settings.logo.attach(io: StringIO.new(@original), filename: 'new-logo.png', content_type: 'image/png')
    end
  end

  test "hidden preview croppers keep originals lazy while thumbnails use derivatives" do
    sign_in @user
    get admin_page_preview_frame_path(@page)
    assert_response :success
    assert_select "[data-image-cropper-target='image'][src*='/blobs/redirect/'][loading='lazy'][decoding='async']", minimum: 1
    assert_select "img.card-content-list__thumbnail[src*='/representations/proxy/'][loading='lazy']", minimum: 1
  end

  test "warming existing images is idempotent and preserves the original" do
    Rails.application.load_tasks unless Rake::Task.task_defined?('media:prepare')
    task = Rake::Task['media:prepare']
    task.reenable
    output, = capture_io { task.invoke }
    assert_includes output, '0 falhas'
    assert_operator @settings.logo.blob.variant_records.count, :>=, 6
    task.reenable
    assert_no_difference 'ActiveStorage::VariantRecord.count' do
      capture_io { task.invoke }
    end
    assert_equal @original, @settings.logo.blob.download
  end
end
