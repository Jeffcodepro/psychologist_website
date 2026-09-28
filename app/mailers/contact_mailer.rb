class ContactMailer < ApplicationMailer
  def notification
    @contact = params.fetch(:contact)
    mail(to: ENV.fetch("CONTACT_RECIPIENT"), reply_to: @contact.email,
         subject: "Novo contato pelo site · ##{@contact.id}")
  end
end
