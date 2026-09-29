class ArticleFromCardService
  def self.call(card:)
    card.with_lock do
      raise ActiveRecord::RecordNotFound unless card.item_kind == 'card' && card.section.draft?
      return card.linked_page if card.linked_page

      pages = card.section.page.tenant.pages
      base = card.title.parameterize.presence || 'texto'
      slug = base
      suffix = 2
      while pages.exists?(slug: slug)
        slug = "#{base}-#{suffix}"
        suffix += 1
      end
      article = pages.create!(name: card.title, slug: slug, content_kind: 'article', show_in_nav: false,
        position: pages.maximum(:position).to_i + 1, description: card.body.to_s.truncate(300),
        description_en: card.body_en.to_s.truncate(300))
      heading = article.sections.create!(section_type: 'hero', position: 1, title: card.title, title_en: card.title_en)
      if card.image.attached?
        heading.image.attach(card.image.blob)
        heading.update!(image_position_x: card.image_position_x, image_position_y: card.image_position_y,
          image_zoom: card.image_zoom, image_shape: card.image_shape, media_adjustments: card.media_adjustments)
      end
      article.sections.create!(section_type: 'text', position: 2, body: card.body, body_en: card.body_en)
      card.update!(linked_page: article)
      ArticleCardService.new(article: article).save! unless card.section.page.slug == 'conteudos'
      article
    end
  end
end
