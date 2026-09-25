class ContactRequest < ApplicationRecord
  attr_accessor :website
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :full_name, :phone, :message, with: ->(value) { value.strip }
  validates :full_name, presence: true, length: { maximum: 150 }
  validates :phone, presence: true, length: { maximum: 30 }
  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, presence: true, length: { maximum: 5000 }
  validate do
    errors.add(:phone, "informe um telefone com DDD") unless phone.to_s.gsub(/\D/, "").length.between?(10, 15)
  end
  scope :recent, -> { order(created_at: :desc) }
end
