class SecureAdminAndTrackContactDelivery < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :locked_at, :datetime
    add_column :contact_requests, :email_delivered_at, :datetime
    add_column :contact_requests, :email_delivery_error, :string
  end
end
