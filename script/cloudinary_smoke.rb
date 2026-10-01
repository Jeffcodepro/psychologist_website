# Run with bin/rails runner script/cloudinary_smoke.rb. Uploads and deletes only a synthetic fixture.
require 'net/http'
require 'tempfile'
require 'zlib'
require 'digest'
require 'json'
require 'securerandom'

abort 'Cloudinary configuration is incomplete.' unless [Cloudinary.config.cloud_name, Cloudinary.config.api_key, Cloudinary.config.api_secret].all?(&:present?)
# Only a newly generated fixture is uploaded; nothing is attached to existing content.
Rails.logger = ActiveSupport::Logger.new(File::NULL)
ActiveStorage.logger = Rails.logger
Cloudinary.config.timeout = 25
key = "cms_smoke_test_#{SecureRandom.hex(16)}"
service = ActiveStorage::Blob.services.fetch('cloudinary')
blob = ActiveStorage::Blob.new(key: key, filename: 'cloudinary-smoke-test.png', content_type: 'image/png', service_name: 'cloudinary')
chunk = ->(name, data) { [data.bytesize].pack('N') + name + data + [Zlib.crc32(name + data)].pack('N') }
width = height = 32
pixels = ("\x00".b + [18, 127, 113].pack('C3') * width) * height
png = "\x89PNG\r\n\x1a\n".b + chunk.call('IHDR', [width, height, 8, 2, 0, 0, 0].pack('NNCCCCC')) + chunk.call('IDAT', Zlib::Deflate.deflate(pixels)) + chunk.call('IEND', ''.b)
fetch_image = lambda do |url|
  uri = URI(url)
  raise 'Unexpected delivery host' unless uri.scheme == 'https' && uri.host == 'res.cloudinary.com'
  Net::HTTP.start(uri.host, uri.port, nil, use_ssl: true, open_timeout: 10, read_timeout: 25, write_timeout: 10) do |http|
    http.max_retries = 0
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Accept'] = 'image/webp,image/png;q=0.8'
    response = http.request(request)
    raise "Image delivery status #{response.code}" unless response.code == '200'
    raise 'Unexpected image content' unless response['Content-Type'].to_s.start_with?('image/') && response.body.bytesize.positive?
    response
  end
end
result = { configured_default_storage: Rails.application.config.active_storage.service.to_s }
attempted = false
stage = 'upload'
begin
  Tempfile.create(['cloudinary-smoke-', '.png']) do |file|
    file.binmode
    file.write(png)
    file.rewind
    attempted = true
    service.upload(blob.key, file, checksum: Digest::MD5.base64digest(png), content_type: 'image/png', overwrite: false)
  end
  result[:upload] = 'ok'
  stage = 'original_delivery'
  original = fetch_image.call(service.url(blob.key, filename: blob.filename, content_type: blob.content_type, secure: true))
  raise 'Original checksum mismatch' unless Digest::MD5.digest(original.body) == Digest::MD5.digest(png)
  result[:original_delivery] = { status: original.code, checksum_matches: true }
  stage = 'optimized_delivery'
  optimized = fetch_image.call(ImageDelivery.cloudinary_url(blob, width: 16))
  result[:optimized_delivery] = { status: optimized.code, content_type: optimized['Content-Type'], bytes: optimized.body.bytesize }
rescue StandardError => error
  safe_message = error.message.dup
  [ENV['CLOUDINARY_URL'], Cloudinary.config.api_key, Cloudinary.config.api_secret].compact.map(&:to_s).reject(&:empty?).each { |secret| safe_message.gsub!(secret, '[REDACTED]') }
  safe_message.gsub!(%r{https?://[^\s]+}, '[URL]')
  safe_message.gsub!(/\b[a-fA-F0-9]{24,}\b/, '[REDACTED]')
  result[:failure] = { stage: stage, error_type: error.class.name, message: safe_message[0, 700] }
ensure
  if attempted
    begin
      deletion = Cloudinary::Uploader.destroy(service.public_id(blob.key), resource_type: 'image', invalidate: true)
      result[:cleanup] = deletion['result']
      result[:removed_from_storage] = !service.exist?(blob.key)
    rescue StandardError => error
      result[:cleanup] = { error_type: error.class.name }
    end
  end
end
if attempted && result[:removed_from_storage] != true
  File.write(Rails.root.join('tmp/cloudinary-smoke-cleanup.txt'), key + "\n", perm: 0o600)
end
puts JSON.pretty_generate(result)
exit(result[:failure] || result[:removed_from_storage] != true ? 1 : 0)
