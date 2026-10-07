require "test_helper"
require "vips"
require "timeout"

class ImageUploadConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "simultaneous identical uploads share one original and release the site lock" do
    tenant = Tenant.create!(name: "Uploads simultâneos", slug: "concurrent-images")
    content = tenant.pages.create!(name: "Imagens", slug: "imagens")
    first = content.sections.create!(section_type: "text", title: "Primeira")
    second = content.sections.create!(section_type: "text", title: "Segunda")
    bytes = Vips::Image.black(9, 7).new_from_image([90, 45, 30]).write_to_buffer(".png")
    entered, release = Queue.new, Queue.new
    upload_count = 0
    counter_lock = Mutex.new
    subscription = ActiveSupport::Notifications.subscribe("service_upload.active_storage") do |*args|
      payload = args.last
      if payload[:service] == "Disk" && Thread.current[:image_upload_test]
        counter_lock.synchronize { upload_count += 1 }
        entered << true
        release.pop
      end
    end
    workers = [first, second].map do |record|
      Thread.new do
        Rails.application.executor.wrap do
          Thread.current[:image_upload_test] = true
          ImageUploadReuse.within_site(tenant.id) do
            record.reload.update!(image: { io: StringIO.new(bytes), filename: "photo.png", content_type: "image/png" })
          end
        ensure
          Thread.current[:image_upload_test] = nil
        end
      end
    end
    Timeout.timeout(10) { entered.pop }
    release << true
    Timeout.timeout(10) { workers.each(&:value) }
    assert_equal 1, upload_count
    assert_equal first.reload.image.blob_id, second.reload.image.blob_id
    assert_equal 1, ImageUploadReuse.blobs_for(tenant.id).count
    assert_equal bytes, first.image.blob.download
    assert_nil ImageUploadReuse::Context.tenant_id
    assert_raises(RuntimeError) { ImageUploadReuse.within_site(tenant.id) { raise "test rollback" } }
    assert_nil ImageUploadReuse::Context.tenant_id
    Timeout.timeout(5) { ImageUploadReuse.within_site(tenant.id) { assert true } }
  ensure
    2.times { release << true } if release
    workers&.each { |worker| worker.join(2); worker.kill if worker.alive? }
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
    blobs = ImageUploadReuse.blobs_for(tenant.id).to_a if tenant&.persisted?
    tenant&.pages&.destroy_all
    tenant&.destroy!
    blobs&.each(&:purge)
  end
end
