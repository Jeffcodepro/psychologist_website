class AddFlexibleSectionMedia < ActiveRecord::Migration[7.1]
  def change
    add_column :sections, :cards_placement, :string, default: "after", null: false
    add_column :sections, :cards_alignment, :string, default: "center", null: false
    add_column :sections, :media_interval_seconds, :integer, default: 5, null: false
    add_column :sections, :use_profile_image, :boolean, default: false, null: false
    add_column :sections, :media_adjustments, :jsonb, default: {}, null: false
    add_column :section_items, :media_adjustments, :jsonb, default: {}, null: false
    add_column :section_items, :item_kind, :string, default: "card", null: false
    add_column :site_settings, :demo_contacts, :boolean, default: false, null: false

    create_table :section_slides do |t|
      t.references :section, null: false, foreign_key: true
      t.string :role, default: "image", null: false
      t.integer :position, default: 0, null: false
      t.integer :image_position_x, default: 50, null: false
      t.integer :image_position_y, default: 50, null: false
      t.decimal :image_zoom, precision: 4, scale: 2, default: 1, null: false
      t.string :image_shape, default: "rounded", null: false
      t.jsonb :media_adjustments, default: {}, null: false
      t.timestamps
    end

    reversible do |dir|
      dir.up do
        execute "UPDATE section_items SET item_kind = 'question' FROM sections WHERE section_items.section_id = sections.id AND sections.section_type = 'faq'"
        execute "UPDATE section_items SET item_kind = 'gallery' FROM sections WHERE section_items.section_id = sections.id AND sections.section_type = 'gallery'"
        # Preserve heroes that intentionally used the global professional photograph.
        execute "UPDATE sections SET use_profile_image = TRUE WHERE section_type = 'hero'"
      end
    end
  end
end
