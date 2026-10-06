# Edits the same draft blocks used by the visual editor and publication service.
# Extra blocks, media and the independently customized teaser remain intact.
class ArticleEditor
  attr_reader :page, :heading, :body_section

  def initialize(page:)
    @page = page
    draft = page.sections.draft.ordered
    next_position = draft.maximum(:position).to_i + 1
    @heading = draft.find_by(section_type: "hero") || page.sections.new(section_type: "hero", position: next_position)
    texts = draft.where(section_type: "text")
    @body_section = texts.find_by("layout_settings ->> 'editorial_role' = ?", "body") ||
      texts.where.not(body: [nil, ""]).first || texts.first ||
      page.sections.new(section_type: "text", position: next_position + 1)
  end

  def save(page_attributes:, content_attributes:, card_section: nil)
    page.assign_attributes(page_attributes)
    content = content_attributes.to_h.stringify_keys
    heading.title = page.name if heading.new_record? || page.name_changed?
    heading.title_en = content["title_en"] if content.key?("title_en")
    body_section.assign_attributes(content.slice("body", "body_en"))
    body_section.layout_settings = body_section.layout_settings.merge("editorial_role" => "body")

    unless Page::EDITORIAL_KINDS.value?(page.content_kind)
      page.errors.add(:content_kind, "escolha Artigo ou Reflexão")
      return false
    end

    Page.transaction do
      page.save!
      heading.save!
      body_section.save!
      placement = ArticleCardService.new(article: page)
      placement.save!(section_choice: card_section) unless placement.existing_card
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    page.errors.add(:base, error.record.errors.full_messages.to_sentence) unless error.record == page
    false
  end
end
