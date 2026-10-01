require "test_helper"
require "minitest/mock"
require "active_storage/service/disk_service"

class MediaStorageMigrationTest < ActiveSupport::TestCase
  setup do
    tenant = Tenant.create!(name: 'Migração', slug: 'migracao')
    settings = tenant.create_site_setting!(professional_name: 'Migração')
    settings.logo.attach(io: StringIO.new('original-preserved'), filename: 'original.png', content_type: 'image/png')
    @blob = settings.logo.blob
    settings.profile_image.attach(@blob)
    @directory = Dir.mktmpdir('cloudinary-migration-test')
    @destination = ActiveStorage::Service::DiskService.new(root: @directory)
    @destination.name = 'cloudinary'
  end

  teardown { FileUtils.remove_entry(@directory) }

  test "verified migration keeps bytes IDs references and source and can be reversed" do
    original_key = @blob.key
    original_ids = @blob.attachments.ids
    registry = ActiveStorage::Blob.services
    fetch = registry.method(:fetch)
    registry.stub(:fetch, ->(name) { name.to_s == 'cloudinary' ? @destination : fetch.call(name) }) do
      migration = MediaStorageMigration.new(source: 'test', target: 'cloudinary')
      assert_equal :moved, migration.move(@blob)
      assert_equal 'cloudinary', @blob.reload.service_name
      assert_equal original_key, @blob.key
      assert_equal original_ids, @blob.attachments.ids
      assert_equal 'original-preserved', @blob.download
      assert fetch.call('test').exist?(original_key)
      assert_equal :skipped, migration.move(@blob)
      assert_equal 1, MediaStorageMigration.originals.where(id: @blob.id).count
      assert_equal :moved, MediaStorageMigration.new(source: 'cloudinary', target: 'test').move(@blob)
      assert_equal 'test', @blob.reload.service_name
      assert @destination.exist?(original_key)
    end
  end

  test "corrupted destination never switches the database or removes the source" do
    @destination.upload(@blob.key, StringIO.new('corrupted'))
    ActiveStorage::Blob.services.stub(:fetch, @destination) do
      migration = MediaStorageMigration.new(source: 'test', target: 'cloudinary')
      assert_raises(ActiveStorage::IntegrityError) { migration.move(@blob) }
    end
    assert_equal 'test', @blob.reload.service_name
    assert_equal 'original-preserved', @blob.download
  end

  test "failed upload leaves original attachments usable" do
    registry = ActiveStorage::Blob.services
    fetch = registry.method(:fetch)
    registry.stub(:fetch, ->(name) { name.to_s == 'cloudinary' ? @destination : fetch.call(name) }) do
      @destination.stub(:upload, ->(*) { raise IOError, 'simulated outage' }) do
        assert_raises(IOError) { MediaStorageMigration.new(source: 'test', target: 'cloudinary').move(@blob) }
      end
    end
    assert_equal 'test', @blob.reload.service_name
    assert_equal 'original-preserved', @blob.download
  end
end
