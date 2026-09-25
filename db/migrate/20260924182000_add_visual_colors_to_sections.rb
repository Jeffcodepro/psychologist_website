class AddVisualColorsToSections < ActiveRecord::Migration[7.1]
  def change
    add_column :sections, :title_color, :string
    add_column :sections, :body_color, :string
    add_column :sections, :accent_color, :string
    add_column :sections, :background_color, :string
    add_column :sections, :overlay_color, :string
  end
end
