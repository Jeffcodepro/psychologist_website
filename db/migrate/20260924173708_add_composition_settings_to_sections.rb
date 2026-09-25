class AddCompositionSettingsToSections < ActiveRecord::Migration[7.1]
  def change
    add_column :sections, :image_zoom, :float, default: 1.0, null: false unless column_exists?(:sections, :image_zoom)
    add_column :sections, :banner_zoom, :float, default: 1.0, null: false unless column_exists?(:sections, :banner_zoom)

    add_column :sections, :image_shape, :string, default: "rounded", null: false
    add_column :sections, :media_layout, :string, default: "text_left", null: false
    add_column :sections, :media_size, :string, default: "medium", null: false
    add_column :sections, :banner_layout, :string, default: "top", null: false
  end
end
