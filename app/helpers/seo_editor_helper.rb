module SeoEditorHelper
  def seo_templates(record, language = "pt-BR")
    name = @admin_site_setting&.professional_name.presence || current_tenant.name
    page = record if record.is_a?(Page)
    heading = page&.name.presence || (language == "en" ? "Home" : "Página inicial")
    home = !page || page.home?
    title = home ? "#{name} | #{language == 'en' ? 'Psychology and psychotherapy' : 'Psicologia e psicoterapia'}" : "#{heading} | #{name}"
    description = if page&.description.present?
      language == "en" ? page.description_en.presence || page.description : page.description
    elsif home
      language == "en" ? "Learn about #{name}'s work in psychology and psychotherapy. Explore the approach and get in touch to ask about appointments." :
        "Conheça o trabalho de #{name} em psicologia e psicoterapia. Saiba mais sobre a abordagem e entre em contato para consultar os atendimentos."
    else
      language == "en" ? "#{heading}: explore this topic with #{name}. Read the full content and learn more about the professional's work." :
        "#{heading}: conheça este tema com #{name}. Leia o conteúdo completo e saiba mais sobre o trabalho da profissional."
    end
    examples = [{ label: "Marca e atuação", title: title, description: description }]
    if language == "en"
      examples += [
        { label: "Escuta e acolhimento", title: "#{home ? 'A space for listening' : heading} | #{name}", description: "A space for listening and reflection with #{name}. #{home ? 'Explore psychotherapy and human development.' : 'Learn more about ' + heading + '.'}" },
        { label: "Nome em primeiro plano", title: "#{name} — #{home ? 'Psychology' : heading}", description: "Meet #{name} and learn about #{home ? 'the professional approach to psychology' : heading}. Explore the site and get in touch." },
        { label: "Convite ao contato", title: "#{home ? 'Psychotherapy' : heading} with #{name}", description: "Learn about #{home ? 'psychotherapy' : heading} with #{name}. Get in touch to ask about the work and available appointments." }
      ]
    else
      examples += [
        { label: "Escuta e acolhimento", title: "#{home ? 'Um espaço de escuta' : heading} | #{name}", description: "Um espaço de escuta e reflexão com #{name}. #{home ? 'Conheça o trabalho em psicoterapia e desenvolvimento humano.' : 'Saiba mais sobre ' + heading + '.'}" },
        { label: "Nome em primeiro plano", title: "#{name} — #{home ? 'Psicologia' : heading}", description: "Conheça #{name} e saiba mais sobre #{home ? 'sua abordagem em psicologia' : heading}. Explore o site e entre em contato." },
        { label: "Convite ao contato", title: "#{home ? 'Psicoterapia' : heading} com #{name}", description: "Saiba mais sobre #{home ? 'psicoterapia' : heading} com #{name}. Entre em contato para conhecer o trabalho e consultar a disponibilidade de atendimentos." }
      ]
    end
    examples.map { |example| example.merge(description: strip_tags(example[:description]).squish.truncate(160, separator: " ")) }
  end

  def seo_example(record, language = "pt-BR")
    seo_templates(record, language).first
  end
end
