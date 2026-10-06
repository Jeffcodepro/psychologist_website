require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  setup do
    @tenant = Tenant.create!(name: "Site", slug: "email", contact_recipient: "owner@example.test")
    @tenant.create_site_setting!(professional_name: "Rosemary Dias")
    @contact = @tenant.contact_requests.create!(full_name: "Pessoa de exemplo", phone: "11999991234", email: "visitor@example.test", message: "Gostaria de conhecer o atendimento.\nTenho disponibilidade às tardes.")
  end

  test "branded multipart email includes fields date reply action and no private access URL" do
    email = ContactMailer.with(contact: @contact).notification
    assert_equal ['owner@example.test'], email.to
    assert_equal ['visitor@example.test'], email.reply_to
    assert email.multipart?
    html = Nokogiri::HTML(email.html_part.decoded)
    assert_equal 'Um novo contato para você', html.at_css('h1').text
    assert_includes html.text, 'Rosemary Dias'
    assert_includes html.text, @contact.created_at.in_time_zone.strftime('%d/%m/%Y às %H:%M')
    assert_equal 'mailto:visitor@example.test', html.at_css('a')['href']
    assert_includes email.text_part.decoded, @contact.message
    assert_not_includes email.html_part.decoded, '/admin/access/'
    if ENV['CMS_VISUAL_QA'] == '1'
      FileUtils.mkdir_p(Rails.root.join('tmp/previews'))
      File.write(Rails.root.join('tmp/previews/contact-email.html'), email.html_part.decoded)
    end
  end

  test "submitted markup is displayed as text and custom checkbox values are formatted by field type" do
    @contact.update!(form_snapshot: [
      { key: 'custom', label: '<img src=x onerror=alert(1)>', type: 'text', required: false, width: 'full' },
      { key: 'opt_in', label: 'Retorno autorizado', type: 'checkbox', required: false, width: 'full' },
      { key: 'number', label: 'Quantidade', type: 'text', required: false, width: 'full' }
    ], answers: { custom: '<script>bad()</script><a href="https://evil.example">link</a>', opt_in: '1', number: '1' })
    html = Nokogiri::HTML(ContactMailer.with(contact: @contact).notification.html_part.decoded)
    assert_empty html.css('script, img, a[href="https://evil.example"]')
    assert_includes html.text, '<script>bad()</script>'
    assert_includes html.text, 'Sim'
    email = ContactMailer.with(contact: @contact).notification
    assert_includes email.text_part.decoded, 'Quantidade: 1'
  end
end
