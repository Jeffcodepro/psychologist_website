class User < ApplicationRecord
  belongs_to :tenant
  devise :database_authenticatable, :recoverable, :validatable, :timeoutable, :lockable, authentication_keys: %i[email tenant_id]

  def active_for_authentication?
    super && admin? && tenant.active?
  end

  def inactive_message
    admin? ? super : :invalid
  end
end
