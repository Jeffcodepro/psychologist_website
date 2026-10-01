namespace :media do
  desc "Prepare cached display images for existing uploads without modifying originals"
  task prepare: :environment do
    types = %w[SiteSetting Section SectionItem SectionSlide]
    completed = 0
    failures = 0
    seen = Set.new
    ActiveStorage::Attachment.where(record_type: types).includes(:blob).find_each do |attachment|
      record = attachment.record
      next unless record
      reflection = record.class.reflect_on_attachment(attachment.name)
      next unless reflection
      next unless attachment.blob.variable?
      next if ImageDelivery.cloudinary?(attachment.blob)

      reflection.named_variants.each_key do |name|
        next unless name.to_s.start_with?("display_")
        next unless seen.add?([attachment.blob_id, name])
        begin
          record.public_send(attachment.name).variant(name).processed
          completed += 1
        rescue StandardError => error
          failures += 1
          warn "Imagem #{attachment.blob_id}, #{name}: #{error.class}"
        end
      end
    end
    puts "#{completed} variantes preparadas; #{failures} falhas. Originais preservados."
    abort "Confira as imagens indicadas e execute novamente para tentar as pendências." if failures.positive?
  end
end

namespace :media do
  desc "List original uploads by storage service"
  task status: :environment do
    puts MediaStorageMigration.originals.group(:service_name).count.inspect
  end

  { migrate_to_cloudinary: ["local", "cloudinary"], restore_local: ["cloudinary", "local"] }.each do |name, (source, target)|
    desc "Copy original images from #{source} to #{target}, verify checksums and keep source files"
    task name => :environment do
      unless [Cloudinary.config.cloud_name, Cloudinary.config.api_key, Cloudinary.config.api_secret].all?(&:present?)
        abort "Configure CLOUDINARY_URL antes de migrar as imagens."
      end
      candidates = MediaStorageMigration.originals.where(service_name: source)
      if ENV["DRY_RUN"] == "1"
        puts "#{candidates.count} imagens para migrar: #{source} -> #{target}. Nenhuma alteração."
        next
      end
      migration = MediaStorageMigration.new(source: source, target: target)
      moved = failures = 0
      candidates.find_each do |blob|
        begin
          moved += 1 if migration.move(blob) == :moved
        rescue StandardError => error
          failures += 1
          warn "Imagem #{blob.id}: #{error.class}. Mantida no serviço de origem."
        end
      end
      puts "#{moved} imagens migradas; #{failures} falhas. Arquivos de origem preservados."
      abort "Confira as pendências antes de repetir a migração." if failures.positive?
    end
  end
end

namespace :media do
  desc "Verify Cloudinary API credentials without uploading files or showing secrets"
  task check_cloudinary: :environment do
    begin
      result = Cloudinary::Api.ping
      abort "Cloudinary não confirmou a conexão." unless result["status"] == "ok"
      puts "Cloudinary conectado. Credenciais verificadas; nenhum arquivo enviado."
    rescue StandardError => error
      abort "Falha na conexão Cloudinary (#{error.class}). Confira o ambiente e o secret CLOUDINARY_URL."
    end
  end
end
