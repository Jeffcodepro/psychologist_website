class TenantProvisioner
  def self.call(name:, slug:, email:, password:, domain: nil, contact_recipient: nil)
    Tenant.transaction do
      tenant = Tenant.create!(name: name, slug: slug, domain: domain, contact_recipient: contact_recipient)
      tenant.create_site_setting!(professional_name: name)
      tenant.users.create!(email: email, password: password, admin: true)
      ensure_contact_page!(tenant)
      { tenant: tenant, login_path: tenant.rotate_admin_link! }
    end
  end

  def self.ensure_contact_page!(tenant)
    return tenant.pages.find_by(slug: "contato") if tenant.pages.exists?(slug: "contato")
    page = tenant.pages.create!(name: "Contato", slug: "contato", nav_label: "Contato", nav_label_en: "Contact", position: tenant.pages.maximum(:position).to_i + 1)
    page.sections.create!(section_type: "contact", title: "Vamos encontrar um momento para conversar.", title_en: "Let’s find a time to talk.", body: "Deixe seus contatos e conte o que trouxe você até aqui. Entrarei em contato para combinar uma primeira conversa.", body_en: "Leave your contact details and share what brings you here. I will get in touch to arrange a first conversation.", position: 1, form_fields: ContactFormSchema::DEFAULT_FIELDS)
    PagePublicationService.new(page: page).call
    page
  end
end
