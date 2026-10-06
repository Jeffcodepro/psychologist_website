module ContactFormsHelper
  def contact_country_options
    language = I18n.locale == :en ? "en" : "pt"
    ContactIdentity::COUNTRIES.sort_by { |country| country.fetch(language) }.map do |country|
      flag = country.fetch("code").codepoints.map { |char| (char + 127397).chr(Encoding::UTF_8) }.join
      ["#{flag} #{country.fetch(language)} (+#{country.fetch('dial')})", country.fetch("code")]
    end
  end

  def contact_form_retry_after
    ContactSubmissionGuard.receipt_retry_after(session, current_tenant.id)
  end
end
