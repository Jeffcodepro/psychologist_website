class SectionSlide < ApplicationRecord
  include MediaAdjustable
  belongs_to :section
  has_one_attached :image

  scope :ordered, -> { order(:position, :id) }
  validates :role, inclusion: { in: %w[image banner] }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :image_position_x, :image_position_y, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :image_zoom, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 3 }
  validates :image_shape, inclusion: { in: Section::IMAGE_SHAPES }
  validate :valid_image

  private

  def valid_image
    unless image.attached?
      errors.add(:image, "selecione uma imagem ou remova este espaço")
      return
    end
    errors.add(:image, "use JPG, PNG ou WebP") unless %w[image/jpeg image/png image/webp].include?(image.blob.content_type)
    errors.add(:image, "deve ter até 10 MB") if image.blob.byte_size > 10.megabytes
  end
end
