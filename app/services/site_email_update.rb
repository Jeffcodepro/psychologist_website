class SiteEmailUpdate
  def self.call(tenant:, email:, admin_id: nil)
    tenant.with_lock do
      admins = tenant.users.where(admin: true)
      admin = admin_id.present? ? admins.find(admin_id) : (admins.first if admins.count == 1)
      raise ArgumentError, "Há mais de um administrador ou nenhum. Informe ADMIN_USER_ID; nenhuma conta foi alterada." unless admin
      admin.update!(email: email.to_s.strip.downcase)
      tenant.update!(contact_recipient: email.to_s.strip.downcase)
      admin
    end
  end
end
