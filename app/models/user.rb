class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :validatable, :timeoutable, :lockable

  def active_for_authentication?
    super && admin?
  end

  def inactive_message
    admin? ? super : :invalid
  end
end
