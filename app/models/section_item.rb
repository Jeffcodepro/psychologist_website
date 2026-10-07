class SectionItem < ApplicationRecord
  include ReusesImageUploads
  include ImageAttachments
  validates_image_attachments :image
  include MediaAdjustable
  include CardPresentation
  KINDS = %w[card question gallery].freeze
  attribute :item_kind, :string, default: nil
  before_validation do
    self.item_kind ||= { "faq" => "question", "gallery" => "gallery" }.fetch(section&.section_type, "card")
  end
  validates :item_kind, inclusion: { in: KINDS }
  scope :cards, -> { where(item_kind: "card") }
  scope :questions, -> { where(item_kind: "question") }
  scope :gallery_items, -> { where(item_kind: "gallery") }

  def editor_label
    { "card" => "card", "question" => "pergunta", "gallery" => "imagem da galeria" }.fetch(item_kind, "card")
  end
  belongs_to :section
  belongs_to :linked_page, class_name: 'Page', optional: true
  validate :destination_belongs_to_site

  has_one_attached :image do |attachable|
    ImageDelivery.configure(attachable, :content)
  end

  attr_accessor :remove_image

  validates :image_position_x, :image_position_y,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :image_zoom,
            numericality: { greater_than_or_equal_to: 0.25, less_than_or_equal_to: 3 }
  validates :image_shape, inclusion: { in: Section::IMAGE_SHAPES }

  validates :title,
            presence: true

  validates :position,
            numericality: {
              only_integer: true
            },
            allow_nil: true

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :id) }

  def localized_title
    if I18n.locale == :en
      title_en.presence || title
    else
      title
    end
  end

  def localized_body
    if I18n.locale == :en
      body_en.presence || body
    else
      body
    end
  end

  private

  def destination_belongs_to_site
    return if linked_page_id.blank?
    unless item_kind == 'card' && linked_page && linked_page.tenant_id == section&.page&.tenant_id
      errors.add(:linked_page_id, 'escolha uma página ou texto deste site')
    end
  end
end
