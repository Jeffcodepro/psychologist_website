class AddContactRequestsAndTextComposition < ActiveRecord::Migration[7.1]
  def change
    add_column :sections, :text_order, :string, default: "title_first", null: false
    add_column :sections, :title_alignment, :string
    add_column :sections, :body_alignment, :string
    create_table :contact_requests do |t|
      t.string :full_name, null: false
      t.string :phone, null: false
      t.string :email, null: false
      t.text :message, null: false
      t.string :source_path
      t.datetime :read_at
      t.timestamps
    end
    reversible do |dir|
      dir.up do
        # A photo must always be an explicit choice for each section.
        execute "UPDATE sections SET use_profile_image = FALSE"
      end
    end
  end
end
