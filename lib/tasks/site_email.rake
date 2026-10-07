namespace :site do
  desc "Update one site admin login and contact recipient atomically; preserve password and SMTP"
  task update_email: :environment do
    domain = ENV.fetch("SITE_DOMAIN")
    email = ENV.fetch("SITE_EMAIL")
    site = Tenant.find_by!(domain: domain)
    admin = SiteEmailUpdate.call(tenant: site, email: email, admin_id: ENV["ADMIN_USER_ID"])
    puts "Site: #{site.domain} · administrador #{admin.id}"
    puts "Acesso e destinatário: #{admin.email}. Senha e conta SMTP preservadas."
  end
end
