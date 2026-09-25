class AddPublishingAndNavigationToSections < ActiveRecord::Migration[7.1]
  def change
    add_column :sections,
               :publication_state,
               :string,
               null: false,
               default: "draft"

    add_column :sections, :anchor, :string

    add_column :sections,
               :show_in_nav,
               :boolean,
               null: false,
               default: false

    add_column :sections, :nav_label, :string
    add_column :sections, :nav_label_en, :string

    add_column :pages, :published_at, :datetime

    add_index :sections,
              [:page_id, :publication_state, :position],
              name: "index_sections_on_page_state_position"

    add_index :sections,
              [:page_id, :publication_state, :anchor],
              unique: true,
              where: "anchor IS NOT NULL",
              name: "index_sections_on_page_state_anchor"
  end
end
