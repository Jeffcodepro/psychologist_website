class AddMediaZoomToSections < ActiveRecord::Migration[7.1]
  def change
    add_column :sections, :banner_zoom, :float, default: 1.0, null: false
    add_column :sections, :image_zoom, :float, default: 1.0, null: false
  end
end
