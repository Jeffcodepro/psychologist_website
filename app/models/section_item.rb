class SectionItem < ApplicationRecord
  belongs_to :section

  has_one_attached :image

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
end
