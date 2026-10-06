class AddNavigationKeyToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :navigation_key, :uuid, default: -> { "gen_random_uuid()" }, null: false
    add_index :sections, [:page_id, :publication_state, :navigation_key], unique: true, name: "index_sections_on_navigation_key"
  end
end
