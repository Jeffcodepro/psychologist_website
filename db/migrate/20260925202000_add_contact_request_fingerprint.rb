class AddContactRequestFingerprint < ActiveRecord::Migration[7.1]
  def change
    add_column :contact_requests, :request_fingerprint, :string
    add_index :contact_requests, [:request_fingerprint, :created_at]
  end
end
