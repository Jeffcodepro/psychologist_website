class IndexContactSubmissionLimits < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :contact_requests, [:tenant_id, :email, :created_at],
      name: "index_contact_requests_on_site_email_time", algorithm: :concurrently
  end
end
