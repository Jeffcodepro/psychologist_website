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
