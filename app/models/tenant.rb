class Tenant < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :pages, dependent: :restrict_with_exception
  has_many :sections, through: :pages
  has_many :contact_requests, dependent: :restrict_with_exception
  has_one :site_setting, dependent: :restrict_with_exception
  normalizes :domain, with: ->(value) { value.to_s.strip.downcase.presence }
  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :domain, uniqueness: true, allow_nil: true, format: { with: /\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\.[a-z]{2,}\z/ }
  validates :contact_recipient, allow_blank: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def rotate_admin_link!
    key = SecureRandom.urlsafe_base64(32)
    update!(login_digest: Digest::SHA256.hexdigest(key))
    "/admin/access/#{key}"
  end

  def self.from_access_key(key)
    return if key.to_s.length < 32 || key.to_s.length > 100
    find_by(login_digest: Digest::SHA256.hexdigest(key), active: true)
  end

  def contact_page
    pages.find_by(slug: "contato")
  end

  def delivery_recipient
    contact_recipient.presence || (primary? ? ENV["CONTACT_RECIPIENT"] : nil)
  end
end
