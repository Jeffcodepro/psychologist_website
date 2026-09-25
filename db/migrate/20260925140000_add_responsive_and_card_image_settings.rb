class AddResponsiveAndCardImageSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :sections, :responsive_settings, :jsonb, default: {}, null: false
    add_column :section_items, :image_position_x, :integer, default: 50, null: false
    add_column :section_items, :image_position_y, :integer, default: 50, null: false
    add_column :section_items, :image_zoom, :decimal, precision: 4, scale: 2, default: 1, null: false
    add_column :section_items, :image_shape, :string, default: "rectangle", null: false
  end
end
