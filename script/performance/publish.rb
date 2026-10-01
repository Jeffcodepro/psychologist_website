# Run during a local load stage to verify availability while publishing.
abort "Only the isolated performance database is allowed." unless Rails.env == "performance" && ApplicationRecord.connection_db_config.database == "psychologist_website_performance"
page = Tenant.find_by!(domain: "rosemary.performance.test").pages.find_by!(slug: "home")
10.times do |index|
  page.sections.draft.ordered.first.update!(body: "Revisão de teste #{index}. " * 10)
  PagePublicationService.new(page: page).call
end
puts "10 synthetic publications completed."
