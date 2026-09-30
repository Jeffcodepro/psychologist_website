class Section < ApplicationRecord
  include EditableButtons
  editable_buttons :action_buttons
  validates :buttons_position, inclusion: { in: %w[before_text between_text after_text] }
  validates :buttons_alignment, inclusion: { in: %w[left center right] }
  include ImageAttachments
  validates_image_attachments :image, :banner
  include ResponsiveSection
  include MediaAdjustable
  SECTION_TYPES = %w[
    hero
    text
    text_image
    cards
    faq
    cta
    gallery
    contact
  ].freeze

  FONT_FAMILIES = FontCatalog::NAMES.keys.freeze

  TEXT_ALIGNMENTS = %w[left center right].freeze
  TEXT_THEMES = %w[dark light].freeze
  BANNER_POSITIONS = %w[center top bottom left right].freeze
  VERTICAL_POSITIONS = %w[top center bottom].freeze
  CARD_ORIENTATIONS = %w[horizontal vertical].freeze

  IMAGE_SHAPES = %w[
    rectangle
    rounded
    square
    circle
    oval
    arch
  ].freeze

  MEDIA_LAYOUTS = %w[
    text_left
    text_right
    media_top
    media_bottom
  ].freeze

  MEDIA_SIZES = %w[
    small
    medium
    large
  ].freeze

  BANNER_LAYOUTS = %w[
    top
    background
    bottom
  ].freeze

  belongs_to :page
  delegate :tenant, :tenant_id, to: :page
  validate do
    errors.add(:form_fields, "campos inválidos") if section_type == "contact" && (!form_fields.is_a?(Array) || !ContactFormSchema.valid?(effective_form_fields))
  end
  validates :title_font_weight, :body_font_weight, inclusion: { in: [300, 400, 500, 600, 700, 800] }
  validates :title_font_style, :body_font_style, inclusion: { in: %w[normal italic] }
  validates :title_line_height, :body_line_height, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 2.5 }
  validates :title_letter_spacing, :body_letter_spacing, numericality: { greater_than_or_equal_to: -1, less_than_or_equal_to: 4 }

  def form_fields_json
    (form_fields.is_a?(Array) ? effective_form_fields : ContactFormSchema::DEFAULT_FIELDS).to_json
  end

  def form_fields_json=(value)
    self.form_fields = JSON.parse(value)
  rescue JSON::ParserError, TypeError
    self.form_fields = nil
  end

  def effective_form_fields
    form_fields.presence || ContactFormSchema::DEFAULT_FIELDS
  end

  has_many :section_items, dependent: :destroy
  has_many :section_slides, dependent: :destroy
  accepts_nested_attributes_for :section_slides, allow_destroy: true,
    reject_if: ->(attrs) { attrs["id"].blank? && attrs["image"].blank? }

  validates :text_order, inclusion: { in: %w[title_first body_first] }
  validates :title_alignment, :body_alignment, inclusion: { in: TEXT_ALIGNMENTS }, allow_blank: true

  def effective_title_alignment
    title_alignment.presence || text_alignment
  end

  def effective_body_alignment
    body_alignment.presence || text_alignment
  end

  validates :cards_placement, inclusion: { in: %w[before after] }
  validates :cards_alignment, inclusion: { in: %w[left center right] }
  validates :media_interval_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 2, less_than_or_equal_to: 30 }

  def slides_for(role)
    section_slides.reject(&:marked_for_destruction?).select { |slide| slide.role == role && slide.image.attached? }.sort_by { |slide| [slide.position, slide.id || 0] }
  end

  has_one_attached :image do |attachable|
    ImageDelivery.configure(attachable, :content)
  end
  has_one_attached :banner do |attachable|
    ImageDelivery.configure(attachable, :banner)
  end
  attr_accessor :remove_image, :remove_banner
  after_save do
    %w[image banner].each { |media| public_send(media).detach if ActiveModel::Type::Boolean.new.cast(public_send("remove_#{media}")) }
  end

  enum :publication_state, {
    draft: "draft",
    published: "published"
  }

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :id) }

  validates :section_type,
            presence: true,
            inclusion: { in: SECTION_TYPES }

  validates :title_font_family,
            inclusion: { in: FONT_FAMILIES }

  validates :body_font_family,
            inclusion: { in: FONT_FAMILIES }

  validates :text_alignment,
            inclusion: { in: TEXT_ALIGNMENTS }

  validates :text_theme,
            inclusion: { in: TEXT_THEMES }

  validates :banner_position,
            inclusion: { in: BANNER_POSITIONS }

  validates :content_vertical_position,
            inclusion: { in: VERTICAL_POSITIONS }

  validates :cards_orientation,
            inclusion: { in: CARD_ORIENTATIONS }

  validates :image_shape,
            inclusion: { in: IMAGE_SHAPES }

  validates :media_layout,
            inclusion: { in: MEDIA_LAYOUTS }

  validates :media_size,
            inclusion: { in: MEDIA_SIZES }

  validates :banner_layout,
            inclusion: { in: BANNER_LAYOUTS }

  validates :title_font_size_desktop,
            :title_font_size_mobile,
            :body_font_size_desktop,
            :body_font_size_mobile,
            numericality: {
              greater_than_or_equal_to: 10,
              less_than_or_equal_to: 120
            }

  validates :banner_overlay,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 90
            }

  validates :image_position_x,
            :image_position_y,
            :banner_position_x,
            :banner_position_y,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100
            }

  validates :image_zoom,
            :banner_zoom,
            numericality: {
              greater_than_or_equal_to: 1.0,
              less_than_or_equal_to: 3.0
            }

  validates :cards_columns_desktop,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 4
            }

  validates :cards_columns_tablet,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 3
            }

  validates :cards_columns_mobile,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 2
            }

  validates :cards_autoplay_seconds,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 2,
              less_than_or_equal_to: 30
            }

  validates :anchor,
            uniqueness: {
              scope: %i[page_id publication_state]
            },
            allow_blank: true

  validates :anchor,
            format: {
              with: /\A[a-z0-9\-]+\z/,
              message: "use apenas letras minúsculas, números e hífens"
            },
            allow_blank: true

  validates :title_color,
            :body_color,
            :accent_color,
            :background_color,
            :overlay_color,
            format: {
              with: /\A#[0-9a-fA-F]{6}\z/,
              message: "deve ser uma cor hexadecimal válida"
            },
            allow_blank: true

  def localized_title
    return title_en.presence || title if I18n.locale == :en

    title
  end

  def localized_body
    return body_en.presence || body if I18n.locale == :en

    body
  end

  def localized_nav_label
    if I18n.locale == :en
      nav_label_en.presence || nav_label.presence || localized_title
    else
      nav_label.presence || title
    end
  end

  def effective_image_position_x
    image_position_x.presence || 50
  end

  def effective_image_position_y
    image_position_y.presence || 50
  end

  def effective_banner_position_x
    banner_position_x.presence || 50
  end

  def effective_banner_position_y
    banner_position_y.presence || 50
  end

  def effective_image_zoom
    image_zoom.presence || 1.0
  end

  def effective_banner_zoom
    banner_zoom.presence || 1.0
  end

  def effective_banner_overlay
    banner_overlay.presence || 0
  end

  def effective_vertical_position
    content_vertical_position.presence || "center"
  end

  def effective_image_shape
    image_shape.presence || "rounded"
  end

  def effective_media_layout
    media_layout.presence || "text_left"
  end

  def effective_media_size
    media_size.presence || "medium"
  end

  def effective_banner_layout
    banner_layout.presence || "top"
  end

  def effective_title_color
    return title_color if title_color.present?
    return "#ffffff" if text_theme == "light"

    "#26342f"
  end

  def effective_body_color
    return body_color if body_color.present?
    return "#f2f3f1" if text_theme == "light"

    "#66736e"
  end

  def effective_accent_color
    accent_color.presence || "#1769ff"
  end

  def effective_background_color
    background_color.presence || "#f8f6f0"
  end

  def effective_overlay_color
    overlay_color.presence || "#17231f"
  end

  def cards_carousel?
    cards_orientation == "horizontal" && !cards_wrap?
  end

  def editor_type_label
    {
      "hero" => "Destaque de abertura",
      "text" => "Texto",
      "text_image" => "Texto + imagem",
      "cards" => "Cards",
      "faq" => "Perguntas frequentes",
      "cta" => "Chamada para ação",
      "gallery" => "Galeria",
      "contact" => "Contato"
    }.fetch(section_type, section_type.humanize)
  end
end
