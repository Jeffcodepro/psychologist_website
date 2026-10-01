# Run with: bin/rails runner -e performance script/performance/seed.rb
abort "Only the isolated performance database is allowed." unless Rails.env == "performance" && ApplicationRecord.connection_db_config.database == "psychologist_website_performance"
abort "Performance data already exists; reuse it, do not seed again." if Tenant.exists?
require "base64"
png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jhXkAAAAASUVORK5CYII=")
blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: "benchmark.png", content_type: "image/png", metadata: { analyzed: true, width: 1, height: 1 })
%w[rosemary thiago].each_with_index do |name, index|
  tenant = Tenant.create!(name: name.capitalize, slug: name, domain: "#{name}.performance.test", primary: index.zero?)
  settings = tenant.create_site_setting!(professional_name: name.capitalize)
  settings.logo.attach(blob)
  home = tenant.pages.create!(name: "Home", slug: "home", show_in_nav: true)
  article = tenant.pages.create!(name: "Artigo", slug: "artigo", content_kind: "article")
  article.sections.create!(section_type: "text", title: "Artigo de #{name}", body: "Conteúdo publicado de demonstração. " * 30)
  PagePublicationService.new(page: article).call
  8.times do |i|
    section = home.sections.create!(section_type: i.zero? ? "hero" : "text_image", title: i.zero? ? "#{name.upcase}_PERFORMANCE_PAGE" : "Seção #{i}", body: "Texto de demonstração para a página pública. " * 10, position: i + 1)
    section.image.attach(blob) if i.even?
  end
  3.times do |group|
    section = home.sections.create!(section_type: "cards", title: "Cards #{group}", position: group + 9)
    12.times do |i|
      card = section.section_items.create!(title: "Card #{group}-#{i}", body: i.even? ? "Resumo do conteúdo. " * 5 : nil, linked_page: article, position: i)
      card.image.attach(blob)
    end
  end
  faq = home.sections.create!(section_type: "faq", title: "Perguntas frequentes", position: 12)
  6.times { |i| faq.section_items.create!(title: "Pergunta #{i}", body: "Uma resposta de demonstração.", position: i) }
  PagePublicationService.new(page: home).call
  TenantProvisioner.ensure_contact_page!(tenant)
end
puts "Created two synthetic sites, each with 12 sections, 36 cards, 6 questions and 41 image references. No real accounts or external uploads."
