class SiteSetting < ApplicationRecord
  belongs_to :tenant
  include EditableButtons
  editable_buttons :header_actions, :footer_actions
  include ImageAttachments
  validates_image_attachments :seo_image
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :instagram, :linkedin, :facebook, :youtube, :tiktok, :threads, :x_twitter, format: { with: /\Ahttps?:\/\/[^\s]+\z/, message: "deve começar com https:// ou http://" }, allow_blank: true
  MAX_IMAGE_SIZE =
    10.megabytes

  ALLOWED_IMAGE_TYPES = %w[
    image/jpeg
    image/png
    image/webp
  ].freeze


  # ==================================================
  # ACTIVE STORAGE
  # ==================================================

  has_one_attached :logo do |attachable|
    ImageDelivery.configure(attachable, :logo)
  end

  has_one_attached :profile_image do |attachable|
    ImageDelivery.configure(attachable, :content)
  end

  has_one_attached :seo_image


  # ==================================================
  # BASIC VALIDATIONS
  # ==================================================

  validates :professional_name,
            presence: true


  # ==================================================
  # IMAGE POSITION
  # ==================================================

  validates :logo_position_x,
            :logo_position_y,
            :profile_image_position_x,
            :profile_image_position_y,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100
            }


  # ==================================================
  # IMAGE ZOOM
  # ==================================================

  validates :logo_zoom,
            :profile_image_zoom,
            numericality: {
              greater_than_or_equal_to: 0.25,
              less_than_or_equal_to: 3.0
            }


  # ==================================================
  # ATTACHMENT VALIDATIONS
  # ==================================================

  validate :validate_logo

  validate :validate_profile_image


  # ==================================================
  # LOCALIZED FOOTER
  # ==================================================

  def localized_footer_text
    if I18n.locale == :en
      footer_text_en.presence ||
        footer_text
    else
      footer_text
    end
  end


  # ==================================================
  # LOGO HELPERS
  # ==================================================

  def effective_logo_zoom
    logo_zoom.presence || 1.0
  end


  def effective_logo_position_x
    logo_position_x.presence || 50
  end


  def effective_logo_position_y
    logo_position_y.presence || 50
  end


  # ==================================================
  # PROFILE IMAGE HELPERS
  # ==================================================

  def effective_profile_image_zoom
    profile_image_zoom.presence || 1.0
  end


  def effective_profile_image_position_x
    profile_image_position_x.presence || 50
  end


  def effective_profile_image_position_y
    profile_image_position_y.presence || 50
  end


  # ==================================================
  # SEO
  # ==================================================

  def seo_configured?
    return false unless respond_to?(:seo_title)
    return false unless respond_to?(:seo_description)

    seo_title.present? &&
      seo_description.present?
  end


  private


  # ==================================================
  # VALIDATE LOGO
  # ==================================================

  def validate_logo
    validate_image_attachment(
      logo,
      :logo
    )
  end


  # ==================================================
  # VALIDATE PROFILE
  # ==================================================

  def validate_profile_image
    validate_image_attachment(
      profile_image,
      :profile_image
    )
  end


  # ==================================================
  # GENERIC ATTACHMENT VALIDATION
  # ==================================================

  def validate_image_attachment(
    attachment,
    attribute
  )
    return unless attachment.attached?

    unless ALLOWED_IMAGE_TYPES.include?(
      attachment.blob.content_type
    )
      errors.add(
        attribute,
        "deve ser JPG, PNG ou WebP"
      )
    end


    if attachment.blob.byte_size >
       MAX_IMAGE_SIZE

      errors.add(
        attribute,
        "deve ter no máximo 10 MB"
      )
    end
  end
end
