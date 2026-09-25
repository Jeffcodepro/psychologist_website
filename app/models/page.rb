class Page < ApplicationRecord
  has_many :sections, dependent: :destroy

  before_validation :generate_slug, on: :create

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :slug,
            format: {
              with: /\A[a-z0-9\-]+\z/,
              message: "use apenas letras minúsculas, números e hífens"
            }

  validates :position,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0
            }

  validates :seo_title,
            length: { maximum: 60 },
            allow_blank: true

  validates :seo_title_en,
            length: { maximum: 60 },
            allow_blank: true

  validates :seo_description,
            length: { maximum: 160 },
            allow_blank: true

  validates :seo_description_en,
            length: { maximum: 160 },
            allow_blank: true

  scope :published, -> { where(published: true) }
  scope :navigation, -> { where(show_in_nav: true).order(:position, :id) }
  scope :ordered, -> { order(:position, :id) }

  def localized_description
    if I18n.locale == :en
      description_en.presence || description
    else
      description
    end
  end

  def localized_nav_label
    if I18n.locale == :en
      nav_label_en.presence || nav_label.presence || name
    else
      nav_label.presence || name
    end
  end

  def localized_seo_title
    if I18n.locale == :en
      seo_title_en.presence || seo_title.presence || name
    else
      seo_title.presence || name
    end
  end

  def localized_seo_description
    if I18n.locale == :en
      seo_description_en.presence || seo_description.presence || localized_description
    else
      seo_description.presence || description
    end
  end

  def generate_slug
    self.slug = name.to_s.parameterize if slug.blank?
  end

  def home?
    slug == "home"
  end

  def seo_configured?
    seo_title.present? && seo_description.present?
  end
end
