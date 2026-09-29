abort "O conteúdo inicial só pode ser criado em um banco sem páginas." if Page.exists?

puts "Criando conteúdo inicial..."

tenant = Tenant.find_or_create_by!(primary: true) { |site| site.name = "Rosemary Dias"; site.slug = "rosemary" }
site_setting = tenant.site_setting || tenant.build_site_setting

site_setting.professional_name =
  site_setting.professional_name.presence || "Rosemary Dias"

site_setting.save!

def create_page!(
  name:,
  slug:,
  position:,
  description:,
  description_en:,
  nav_label:,
  nav_label_en:,
  seo_title:,
  seo_title_en:,
  seo_description:,
  seo_description_en:
)
  Tenant.find_by!(primary: true).pages.create!(
    name: name,
    slug: slug,
    position: position,
    description: description,
    description_en: description_en,
    nav_label: nav_label,
    nav_label_en: nav_label_en,
    show_in_nav: true,
    published: false,
    seo_title: seo_title,
    seo_title_en: seo_title_en,
    seo_description: seo_description,
    seo_description_en: seo_description_en
  )
end

def create_section!(
  page:,
  section_type:,
  position:,
  title:,
  title_en:,
  body: nil,
  body_en: nil,
  anchor: nil,
  text_alignment: "left",
  cards_orientation: "horizontal",
  cards_wrap: true,
  cards_columns_desktop: 3,
  cards_columns_tablet: 2,
  cards_columns_mobile: 1,
  items: []
)
  section = page.sections.create!(
    section_type: section_type,
    publication_state: "draft",
    position: position,
    visible: true,
    title: title,
    title_en: title_en,
    body: body,
    body_en: body_en,
    anchor: anchor,
    show_in_nav: false,
    text_alignment: text_alignment,
    cards_orientation: cards_orientation,
    cards_wrap: cards_wrap,
    cards_columns_desktop: cards_columns_desktop,
    cards_columns_tablet: cards_columns_tablet,
    cards_columns_mobile: cards_columns_mobile,
    cards_autoplay: true,
    cards_autoplay_seconds: 5
  )

  items.each_with_index do |item, index|
    section.section_items.create!(
      title: item[:title],
      title_en: item[:title_en],
      body: item[:body],
      body_en: item[:body_en],
      position: index + 1,
      visible: true
    )
  end

  section
end

home = create_page!(
  name: "Home",
  slug: "home",
  position: 1,
  description: "Página inicial e apresentação geral do trabalho profissional.",
  description_en: "Homepage and general introduction to the professional work.",
  nav_label: "Home",
  nav_label_en: "Home",
  seo_title: "Rosemary Dias | Psicologia e Desenvolvimento Humano",
  seo_title_en: "Rosemary Dias | Psychology and Human Development",
  seo_description: "Psicologia, psicoterapia e desenvolvimento humano em um espaço de escuta, compreensão e transformação.",
  seo_description_en: "Psychology, psychotherapy and human development in a space for listening, understanding and transformation."
)

create_section!(
  page: home,
  section_type: "hero",
  position: 1,
  title: "Compreender o que você vive pode abrir espaço para novos caminhos.",
  title_en: "Understanding what you are experiencing can open space for new paths.",
  body: "Psicologia e desenvolvimento humano com escuta, cuidado e profundidade para pessoas que desejam compreender suas experiências e construir mudanças possíveis.",
  body_en: "Psychology and human development with listening, care and depth for people who wish to understand their experiences and create meaningful change.",
  anchor: "hero"
)

create_section!(
  page: home,
  section_type: "text",
  position: 2,
  title: "Como posso ajudar?",
  title_en: "How can I help?",
  body: "Nem sempre precisamos ter todas as respostas para começar. O processo pode ser um espaço para compreender emoções, reconhecer padrões, atravessar mudanças e desenvolver novas formas de se relacionar consigo e com o mundo.",
  body_en: "We do not need to have every answer before we begin. The process can offer space to understand emotions, recognise patterns, navigate change and develop new ways of relating to yourself and the world.",
  anchor: "como-posso-ajudar",
  text_alignment: "center"
)

create_section!(
  page: home,
  section_type: "cards",
  position: 3,
  title: "Áreas de atuação",
  title_en: "Areas of practice",
  body: "Dois caminhos que podem se complementar de acordo com o momento e os objetivos de cada pessoa.",
  body_en: "Two paths that may complement each other according to each person's moment and goals.",
  anchor: "areas-de-atuacao",
  cards_columns_desktop: 2,
  items: [
    {
      title: "Psicoterapia",
      title_en: "Psychotherapy",
      body: "Um espaço de escuta e elaboração para compreender emoções, relações, mudanças e questões que atravessam a vida.",
      body_en: "A space for listening and reflection to understand emotions, relationships, changes and the experiences that shape life."
    },
    {
      title: "Desenvolvimento Humano",
      title_en: "Human Development",
      body: "Processos voltados ao autoconhecimento, escolhas, comunicação, relações e desenvolvimento pessoal.",
      body_en: "Processes focused on self-knowledge, choices, communication, relationships and personal development."
    }
  ]
)

create_section!(
  page: home,
  section_type: "text_image",
  position: 4,
  title: "Minha abordagem",
  title_en: "My approach",
  body: "Cada pessoa chega com uma história, um contexto e uma forma singular de experimentar o mundo. O trabalho parte dessa singularidade para construir um processo respeitoso, reflexivo e possível.",
  body_en: "Each person arrives with a story, a context and a unique way of experiencing the world. The work begins from this individuality to build a respectful, reflective and meaningful process.",
  anchor: "minha-abordagem"
)

create_section!(
  page: home,
  section_type: "text_image",
  position: 5,
  title: "Sobre Rosemary",
  title_en: "About Rosemary",
  body: "Psicologia, escuta e desenvolvimento humano se encontram em uma prática voltada à compreensão da experiência de cada pessoa. Nesta área do site você poderá conhecer sua trajetória, formação, experiência e valores profissionais.",
  body_en: "Psychology, listening and human development come together in a practice focused on understanding each person's experience. Here you can learn about her journey, education, experience and professional values.",
  anchor: "sobre"
)

create_section!(
  page: home,
  section_type: "cards",
  position: 6,
  title: "Conteúdos e reflexões",
  title_en: "Content and reflections",
  body: "Textos para ampliar conversas sobre emoções, relações, escolhas e desenvolvimento humano.",
  body_en: "Articles and reflections expanding conversations about emotions, relationships, choices and human development.",
  anchor: "conteudos",
  items: [
    {
      title: "Autoconhecimento",
      title_en: "Self-awareness",
      body: "Reflexões sobre como perceber padrões, necessidades e possibilidades de mudança.",
      body_en: "Reflections on recognising patterns, needs and possibilities for change."
    },
    {
      title: "Relações",
      title_en: "Relationships",
      body: "Conversas sobre vínculos, limites, comunicação e formas de se relacionar.",
      body_en: "Conversations about connection, boundaries, communication and ways of relating."
    },
    {
      title: "Mudanças",
      title_en: "Change",
      body: "Conteúdos sobre transições, escolhas e momentos em que a vida pede reorganização.",
      body_en: "Content about transitions, choices and moments when life calls for reorganisation."
    }
  ]
)

create_section!(
  page: home,
  section_type: "faq",
  position: 7,
  title: "Perguntas frequentes",
  title_en: "Frequently asked questions",
  anchor: "faq",
  items: [
    {
      title: "Como saber se este é um bom momento para iniciar psicoterapia?",
      title_en: "How do I know if this is a good time to start psychotherapy?",
      body: "Não é necessário esperar por uma situação extrema. A psicoterapia também pode ser procurada quando existe o desejo de compreender melhor experiências, emoções, relações ou escolhas.",
      body_en: "You do not need to wait for an extreme situation. Psychotherapy can also begin from a wish to better understand experiences, emotions, relationships or choices."
    },
    {
      title: "Como funciona o primeiro encontro?",
      title_en: "What happens in the first session?",
      body: "O primeiro encontro é um espaço inicial de conversa para compreender o que motivou a busca e apresentar como o processo pode ser conduzido.",
      body_en: "The first session is an initial conversation to understand what brought you to therapy and to discuss how the process may be conducted."
    },
    {
      title: "Os atendimentos podem ser online?",
      title_en: "Can sessions take place online?",
      body: "As modalidades disponíveis podem ser apresentadas no momento do contato, de acordo com a organização atual da agenda profissional.",
      body_en: "Available session formats can be discussed when you get in touch, according to the current professional schedule."
    }
  ]
)

create_section!(
  page: home,
  section_type: "cta",
  position: 8,
  title: "Um processo pode começar com uma conversa.",
  title_en: "A process can begin with a conversation.",
  body: "Entre em contato para conhecer melhor o trabalho e entender qual caminho faz sentido para o seu momento.",
  body_en: "Get in touch to learn more about the work and understand which path may make sense for your current moment.",
  anchor: "cta"
)

psychotherapy = create_page!(
  name: "Psicoterapia",
  slug: "psicoterapia",
  position: 2,
  description: "Página dedicada ao processo de psicoterapia.",
  description_en: "Page dedicated to the psychotherapy process.",
  nav_label: "Psicoterapia",
  nav_label_en: "Psychotherapy",
  seo_title: "Psicoterapia | Rosemary Dias",
  seo_title_en: "Psychotherapy | Rosemary Dias",
  seo_description: "Conheça o trabalho de psicoterapia, possibilidades de cuidado e como funciona o processo.",
  seo_description_en: "Learn about psychotherapy, possibilities for care and how the process works."
)

create_section!(
  page: psychotherapy,
  section_type: "hero",
  position: 1,
  title: "Psicoterapia como espaço de escuta, compreensão e elaboração.",
  title_en: "Psychotherapy as a space for listening, understanding and reflection.",
  body: "Um processo construído a partir da sua história, do seu momento e das questões que hoje pedem atenção.",
  body_en: "A process built around your story, your current moment and the questions that need attention today.",
  anchor: "hero"
)

create_section!(
  page: psychotherapy,
  section_type: "text",
  position: 2,
  title: "Quando procurar psicoterapia?",
  title_en: "When might psychotherapy be helpful?",
  body: "A busca pode acontecer em momentos de sofrimento, mudanças, conflitos, dúvidas ou simplesmente a partir do desejo de se conhecer melhor. Não existe uma única razão correta para começar.",
  body_en: "People may seek psychotherapy during times of distress, change, conflict, uncertainty or simply from a desire for greater self-understanding. There is no single correct reason to begin.",
  anchor: "quando-procurar"
)

create_section!(
  page: psychotherapy,
  section_type: "cards",
  position: 3,
  title: "Como posso ajudar",
  title_en: "How I can help",
  anchor: "como-posso-ajudar",
  cards_columns_desktop: 2,
  items: [
    {
      title: "Emoções e autoconsciência",
      title_en: "Emotions and self-awareness",
      body: "Compreender sentimentos, necessidades, reações e padrões que se repetem.",
      body_en: "Understanding feelings, needs, reactions and recurring patterns."
    },
    {
      title: "Relações e vínculos",
      title_en: "Relationships and connection",
      body: "Refletir sobre comunicação, limites, conflitos e formas de construir relações.",
      body_en: "Reflecting on communication, boundaries, conflict and ways of building relationships."
    },
    {
      title: "Mudanças e transições",
      title_en: "Change and transitions",
      body: "Atravessar períodos de transformação e reorganizar escolhas diante de novos contextos.",
      body_en: "Navigating periods of transformation and reorganising choices in new circumstances."
    },
    {
      title: "Escolhas e desenvolvimento",
      title_en: "Choices and development",
      body: "Ampliar a compreensão sobre si para tomar decisões mais conscientes.",
      body_en: "Deepening self-understanding to make more conscious decisions."
    }
  ]
)

create_section!(
  page: psychotherapy,
  section_type: "cards",
  position: 4,
  title: "Como funciona",
  title_en: "How it works",
  anchor: "como-funciona",
  items: [
    {
      title: "Primeiro contato",
      title_en: "First contact",
      body: "Um primeiro contato para conhecer a demanda e combinar os próximos passos.",
      body_en: "An initial contact to understand your needs and agree on the next steps."
    },
    {
      title: "Primeiro encontro",
      title_en: "First session",
      body: "Um espaço inicial para compreender o contexto e as expectativas em relação ao processo.",
      body_en: "An initial space to understand the context and expectations for the process."
    },
    {
      title: "Processo",
      title_en: "The process",
      body: "Os encontros constroem gradualmente um espaço de reflexão e elaboração.",
      body_en: "Sessions gradually build a space for reflection and working through experiences."
    }
  ]
)

create_section!(
  page: psychotherapy,
  section_type: "text_image",
  position: 5,
  title: "Abordagem",
  title_en: "Approach",
  body: "O processo considera a pessoa em sua singularidade, história e contexto, evitando respostas prontas e construindo reflexões que façam sentido para sua experiência.",
  body_en: "The process considers each person in their individuality, history and context, avoiding ready-made answers and building reflections that make sense for their experience.",
  anchor: "abordagem"
)

create_section!(
  page: psychotherapy,
  section_type: "faq",
  position: 6,
  title: "Perguntas frequentes",
  title_en: "Frequently asked questions",
  anchor: "faq",
  items: [
    {
      title: "Quanto tempo dura um processo de psicoterapia?",
      title_en: "How long does psychotherapy take?",
      body: "A duração varia porque cada processo possui objetivos, contexto e ritmo próprios.",
      body_en: "Duration varies because each process has its own goals, context and pace."
    },
    {
      title: "Preciso chegar sabendo exatamente o que quero trabalhar?",
      title_en: "Do I need to know exactly what I want to work on?",
      body: "Não. Muitas vezes compreender melhor a própria demanda já faz parte do processo.",
      body_en: "No. Understanding what you would like to work on can itself be part of the process."
    }
  ]
)

create_section!(
  page: psychotherapy,
  section_type: "cta",
  position: 7,
  title: "Quer conhecer melhor como funciona a psicoterapia?",
  title_en: "Would you like to learn more about psychotherapy?",
  body: "Entre em contato para conversar sobre o processo e disponibilidade.",
  body_en: "Get in touch to discuss the process and availability.",
  anchor: "cta"
)

human_development = create_page!(
  name: "Desenvolvimento Humano",
  slug: "desenvolvimento-humano",
  position: 3,
  description: "Página dedicada aos processos de desenvolvimento humano.",
  description_en: "Page dedicated to human development processes.",
  nav_label: "Desenvolvimento Humano",
  nav_label_en: "Human Development",
  seo_title: "Desenvolvimento Humano | Rosemary Dias",
  seo_title_en: "Human Development | Rosemary Dias",
  seo_description: "Autoconhecimento, comunicação, escolhas e desenvolvimento pessoal em processos construídos com propósito.",
  seo_description_en: "Self-awareness, communication, choices and personal development through purposeful processes."
)

create_section!(
  page: human_development,
  section_type: "hero",
  position: 1,
  title: "Desenvolvimento humano é ampliar possibilidades.",
  title_en: "Human development is about expanding possibilities.",
  body: "Um espaço para reconhecer recursos, compreender escolhas e desenvolver novas formas de agir, comunicar e se relacionar.",
  body_en: "A space to recognise resources, understand choices and develop new ways of acting, communicating and relating.",
  anchor: "hero"
)

create_section!(
  page: human_development,
  section_type: "text",
  position: 2,
  title: "O que é",
  title_en: "What it is",
  body: "O desenvolvimento humano reúne processos de reflexão e aprendizagem voltados ao crescimento pessoal, relacional e profissional.",
  body_en: "Human development brings together reflective and learning processes focused on personal, relational and professional growth.",
  anchor: "o-que-e"
)

create_section!(
  page: human_development,
  section_type: "cards",
  position: 3,
  title: "Para quem",
  title_en: "Who it is for",
  anchor: "para-quem",
  items: [
    {
      title: "Pessoas em momentos de mudança",
      title_en: "People going through change",
      body: "Para quem está reorganizando caminhos, decisões ou prioridades.",
      body_en: "For those reorganising paths, decisions or priorities."
    },
    {
      title: "Pessoas buscando autoconhecimento",
      title_en: "People seeking self-awareness",
      body: "Para quem deseja compreender melhor habilidades, valores, escolhas e relações.",
      body_en: "For those wishing to better understand abilities, values, choices and relationships."
    },
    {
      title: "Profissionais e lideranças",
      title_en: "Professionals and leaders",
      body: "Para quem busca desenvolver comunicação, relações e presença profissional.",
      body_en: "For those seeking to develop communication, relationships and professional presence."
    }
  ]
)

create_section!(
  page: human_development,
  section_type: "cards",
  position: 4,
  title: "Temas trabalhados",
  title_en: "Themes",
  anchor: "temas",
  items: [
    {
      title: "Autoconhecimento",
      title_en: "Self-awareness",
      body: "Valores, recursos, necessidades e padrões pessoais.",
      body_en: "Values, resources, needs and personal patterns."
    },
    {
      title: "Comunicação",
      title_en: "Communication",
      body: "Escuta, clareza, posicionamento e relações.",
      body_en: "Listening, clarity, positioning and relationships."
    },
    {
      title: "Escolhas",
      title_en: "Choices",
      body: "Critérios, prioridades e decisões mais conscientes.",
      body_en: "Criteria, priorities and more conscious decision-making."
    },
    {
      title: "Desenvolvimento",
      title_en: "Development",
      body: "Construção de novas competências e possibilidades.",
      body_en: "Building new skills and possibilities."
    }
  ]
)

create_section!(
  page: human_development,
  section_type: "text",
  position: 5,
  title: "Como funciona",
  title_en: "How it works",
  body: "O formato pode ser construído de acordo com os objetivos e contexto do processo, mantendo clareza sobre expectativas, temas e desenvolvimento ao longo do percurso.",
  body_en: "The format can be built according to the goals and context of the process, maintaining clarity about expectations, themes and development throughout the journey.",
  anchor: "como-funciona"
)

create_section!(
  page: human_development,
  section_type: "faq",
  position: 6,
  title: "Perguntas frequentes",
  title_en: "Frequently asked questions",
  anchor: "faq",
  items: [
    {
      title: "Desenvolvimento humano é psicoterapia?",
      title_en: "Is human development psychotherapy?",
      body: "Não necessariamente. São propostas diferentes e a modalidade adequada depende do objetivo e da natureza da demanda.",
      body_en: "Not necessarily. They are different approaches and the appropriate format depends on the objective and nature of the need."
    },
    {
      title: "O processo pode ter um objetivo específico?",
      title_en: "Can the process have a specific objective?",
      body: "Sim. É possível organizar o trabalho em torno de temas e objetivos definidos.",
      body_en: "Yes. The work can be organised around specific themes and objectives."
    }
  ]
)

create_section!(
  page: human_development,
  section_type: "cta",
  position: 7,
  title: "Desenvolvimento começa quando novas perguntas se tornam possíveis.",
  title_en: "Development begins when new questions become possible.",
  body: "Entre em contato para conhecer as possibilidades de trabalho.",
  body_en: "Get in touch to learn about the available possibilities.",
  anchor: "cta"
)

about = create_page!(
  name: "Sobre",
  slug: "sobre",
  position: 4,
  description: "Apresentação da trajetória, formação, experiência e valores profissionais.",
  description_en: "Professional journey, education, experience and values.",
  nav_label: "Sobre",
  nav_label_en: "About",
  seo_title: "Sobre Rosemary Dias | Psicologia",
  seo_title_en: "About Rosemary Dias | Psychology",
  seo_description: "Conheça a trajetória, formação, experiência e os valores que orientam o trabalho de Rosemary Dias.",
  seo_description_en: "Learn about Rosemary Dias' journey, education, experience and professional values."
)

create_section!(
  page: about,
  section_type: "hero",
  position: 1,
  title: "Uma trajetória construída em torno de pessoas, escuta e desenvolvimento.",
  title_en: "A journey built around people, listening and development.",
  body: "Conheça a profissional por trás do trabalho, sua trajetória e os princípios que orientam sua prática.",
  body_en: "Meet the professional behind the work, her journey and the principles that guide her practice.",
  anchor: "hero"
)

create_section!(
  page: about,
  section_type: "text_image",
  position: 2,
  title: "Trajetória",
  title_en: "Journey",
  body: "Use este espaço para apresentar os principais momentos da trajetória profissional, experiências que influenciaram sua prática e o caminho que levou à atuação atual.",
  body_en: "Use this space to introduce the main moments of the professional journey, experiences that influenced the practice and the path that led to the current work.",
  anchor: "trajetoria"
)

create_section!(
  page: about,
  section_type: "cards",
  position: 3,
  title: "Formação",
  title_en: "Education",
  anchor: "formacao",
  items: [
    {
      title: "Formação acadêmica",
      title_en: "Academic education",
      body: "Cadastre aqui a graduação e principais formações acadêmicas.",
      body_en: "Add academic degrees and main educational qualifications here."
    },
    {
      title: "Especializações",
      title_en: "Specialisations",
      body: "Cadastre aqui especializações, pós-graduações e formações complementares.",
      body_en: "Add specialisations, postgraduate study and complementary education here."
    },
    {
      title: "Formação continuada",
      title_en: "Continuing education",
      body: "Cadastre cursos e estudos relevantes para a prática profissional.",
      body_en: "Add courses and studies relevant to professional practice."
    }
  ]
)

create_section!(
  page: about,
  section_type: "cards",
  position: 4,
  title: "Experiência",
  title_en: "Experience",
  anchor: "experiencia",
  items: [
    {
      title: "Atuação profissional",
      title_en: "Professional practice",
      body: "Apresente os principais contextos de atuação profissional.",
      body_en: "Introduce the main contexts of professional practice."
    },
    {
      title: "Projetos e iniciativas",
      title_en: "Projects and initiatives",
      body: "Inclua projetos, iniciativas ou trabalhos relevantes desenvolvidos ao longo da trajetória.",
      body_en: "Include relevant projects, initiatives or work developed throughout the professional journey."
    }
  ]
)

create_section!(
  page: about,
  section_type: "cards",
  position: 5,
  title: "Valores",
  title_en: "Values",
  anchor: "valores",
  items: [
    {
      title: "Escuta",
      title_en: "Listening",
      body: "Um processo começa pela disponibilidade para compreender a experiência do outro.",
      body_en: "A process begins with openness to understanding another person's experience."
    },
    {
      title: "Respeito",
      title_en: "Respect",
      body: "Cada trajetória possui contexto, ritmo e necessidades próprias.",
      body_en: "Every journey has its own context, pace and needs."
    },
    {
      title: "Desenvolvimento",
      title_en: "Development",
      body: "Mudanças consistentes podem surgir da compreensão e da construção gradual de novas possibilidades.",
      body_en: "Meaningful change can emerge from understanding and the gradual construction of new possibilities."
    }
  ]
)

create_section!(
  page: about,
  section_type: "cta",
  position: 6,
  title: "Conhecer o profissional também faz parte da escolha.",
  title_en: "Getting to know the professional is also part of the choice.",
  body: "Entre em contato caso queira saber mais sobre o trabalho.",
  body_en: "Get in touch if you would like to learn more about the work.",
  anchor: "cta"
)

content_page = create_page!(
  name: "Conteúdos",
  slug: "conteudos",
  position: 5,
  description: "Artigos e reflexões sobre psicologia, relações e desenvolvimento humano.",
  description_en: "Articles and reflections about psychology, relationships and human development.",
  nav_label: "Conteúdos",
  nav_label_en: "Content",
  seo_title: "Conteúdos e Reflexões | Rosemary Dias",
  seo_title_en: "Content and Reflections | Rosemary Dias",
  seo_description: "Artigos e reflexões sobre psicologia, emoções, relações, escolhas e desenvolvimento humano.",
  seo_description_en: "Articles and reflections about psychology, emotions, relationships, choices and human development."
)

create_section!(
  page: content_page,
  section_type: "cards",
  position: 1,
  title: "Destaques",
  title_en: "Highlights",
  body: "Uma seleção de temas para começar a explorar.",
  body_en: "A selection of themes to begin exploring.",
  anchor: "destaques",
  items: [
    {
      title: "O que significa se conhecer melhor?",
      title_en: "What does it mean to know yourself better?",
      body: "Uma reflexão sobre autoconhecimento para além de respostas prontas.",
      body_en: "A reflection on self-awareness beyond ready-made answers."
    },
    {
      title: "Mudanças também exigem elaboração",
      title_en: "Change also requires reflection",
      body: "Por que transições podem mobilizar emoções mesmo quando são desejadas.",
      body_en: "Why transitions can stir emotions even when they are desired."
    },
    {
      title: "Limites e relações",
      title_en: "Boundaries and relationships",
      body: "Uma conversa sobre limites, comunicação e cuidado nas relações.",
      body_en: "A conversation about boundaries, communication and care in relationships."
    }
  ]
)

create_section!(
  page: content_page,
  section_type: "cards",
  position: 2,
  title: "Artigos",
  title_en: "Articles",
  anchor: "artigos",
  items: [
    {
      title: "Autoconhecimento e escolhas",
      title_en: "Self-awareness and choices",
      body: "Como compreender valores e prioridades pode ampliar a qualidade das decisões.",
      body_en: "How understanding values and priorities can improve decision-making."
    },
    {
      title: "Comunicação nas relações",
      title_en: "Communication in relationships",
      body: "Reflexões sobre escuta, posicionamento e construção de diálogo.",
      body_en: "Reflections on listening, positioning and building dialogue."
    },
    {
      title: "Processos de mudança",
      title_en: "Processes of change",
      body: "Por que mudar envolve mais do que simplesmente decidir fazer algo diferente.",
      body_en: "Why change involves more than simply deciding to do something differently."
    }
  ]
)

create_section!(
  page: content_page,
  section_type: "cards",
  position: 3,
  title: "Reflexões",
  title_en: "Reflections",
  anchor: "reflexoes",
  items: [
    {
      title: "Nem toda pausa é ausência de movimento.",
      title_en: "Not every pause means there is no movement.",
      body: "Alguns processos acontecem enquanto reorganizamos internamente aquilo que estamos vivendo.",
      body_en: "Some processes happen while we internally reorganise what we are experiencing."
    },
    {
      title: "Compreender também é uma forma de mudança.",
      title_en: "Understanding is also a form of change.",
      body: "Quando algo ganha nome e contexto, novas possibilidades podem aparecer.",
      body_en: "When something gains a name and context, new possibilities can emerge."
    },
    {
      title: "Escolher também significa renunciar.",
      title_en: "Choosing also means letting go.",
      body: "Toda decisão importante envolve reconhecer caminhos possíveis e aquilo que não seguirá conosco.",
      body_en: "Every important decision involves recognising possible paths and what will not continue with us."
    }
  ]
)

TenantProvisioner.ensure_contact_page!(tenant)

puts "Publicando páginas..."

Page.find_each do |page|
  PagePublicationService.new(page: page).call
end

puts "Seed concluído."
puts "#{Page.count} páginas criadas."
puts "#{Section.draft.count} seções em rascunho."
puts "#{Section.published.count} seções publicadas."
