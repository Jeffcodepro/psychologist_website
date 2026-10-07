class ArticleCardService
  AREAS = { 'destaques' => ['Destaques', 'Highlights'], 'artigos' => ['Artigos', 'Articles'], 'reflexoes' => ['Reflexões', 'Reflections'] }.freeze

  def initialize(article:)
    @article = article
  end

  def contents_page
    @article.tenant.pages.site_pages.find_by(slug: 'conteudos')
  end

  def sections
    contents_page ? contents_page.sections.draft.ordered : Section.none
  end

  def existing_card
    return unless contents_page
    @article.linking_cards.cards.joins(:section)
      .where(sections: { page_id: contents_page.id, publication_state: 'draft' }).ordered.first
  end

  def section_options
    sections.map { |section| [section.title.presence || section.editor_type_label, section.id.to_s] } +
      AREAS.filter_map { |key, labels| ["#{labels.first} · criar seção", "new:#{key}"] unless area_section(key) }
  end

  def default_section_choice
    return existing_card.section_id.to_s if existing_card
    key = @article.content_kind == 'reflection' ? 'reflexoes' : 'artigos'
    area_section(key)&.id&.to_s || "new:#{key}"
  end

  def build
    existing_card || begin
      heading = @article.sections.draft.ordered.find_by(section_type: 'hero')
      body = @article.sections.draft.ordered.where.not(body: [nil, '']).first
      card = SectionItem.new(item_kind: 'card', linked_page: @article, visible: true,
        title: heading&.title.presence || @article.name, title_en: heading&.title_en,
        body: excerpt(@article.description.presence || body&.body),
        body_en: excerpt(@article.description_en.presence || body&.body_en))
      source = @article.sections.draft.ordered.detect { |section| section.image.attached? || section.video_available? }
      if source
        card.video.attach(source.video.blob) if source.video.attached?
        card.video_settings = source.video_settings.slice("image")
        card.image.attach(source.image.blob) if source.image.attached?
        card.assign_attributes(source.attributes.slice('image_position_x', 'image_position_y', 'image_zoom', 'image_shape', 'media_adjustments'))
      end
      card
    end
  end

  def save!(attributes: {}, section_choice: nil)
    @article.tenant.with_lock do
      card = build
      target = target_section!(section_choice.presence || default_section_choice)
      card.position = target.section_items.maximum(:position).to_i + 1 if card.new_record? || card.section_id != target.id
      card.section = target
      card.assign_attributes(attributes)
      card.linked_page = @article
      card.save!
      card
    end
  end

  private

  def excerpt(value)
    FormattedContent.plain(value).truncate(240, separator: ' ')
  end

  def area_section(key)
    sections.detect { |section| section.anchor == key || section.title.to_s.parameterize == key }
  end

  def target_section!(choice)
    return sections.find(choice) if choice.to_s.match?(/\A\d+\z/)
    key = choice.to_s.delete_prefix('new:')
    raise ActiveRecord::RecordNotFound unless choice == "new:#{key}" && AREAS.key?(key)
    return area_section(key) if area_section(key)
    page = contents_page || @article.tenant.pages.create!(name: 'Conteúdos', slug: 'conteudos',
      nav_label: 'Conteúdos', nav_label_en: 'Content', show_in_nav: true,
      position: @article.tenant.pages.maximum(:position).to_i + 1)
    page.sections.create!(section_type: 'cards', title: AREAS[key].first, title_en: AREAS[key].last,
      anchor: key, position: page.sections.draft.maximum(:position).to_i + 1)
  end
end
