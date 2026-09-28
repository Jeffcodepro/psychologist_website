class SectionItem < ApplicationRecord
  include ImageAttachments
  validates_image_attachments :image
  include MediaAdjustable
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

  has_one_attached :image

  attr_accessor :remove_image
  after_save :detach_removed_image

  validates :image_position_x, :image_position_y,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :image_zoom,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 3 }
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

  def detach_removed_image
    # Published cards may still reference the same blob.
    image.detach if ActiveModel::Type::Boolean.new.cast(remove_image)
  end
end
