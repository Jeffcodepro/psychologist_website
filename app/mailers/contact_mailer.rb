class ContactMailer < ApplicationMailer
  def notification
    @contact = params.fetch(:contact)
    mail(to: @contact.tenant.delivery_recipient, reply_to: @contact.email.presence,
         subject: "Novo contato pelo site · ##{@contact.id}")
  end
end
