class AddImagePositionCoordinatesToSections < ActiveRecord::Migration[7.1]
  def change
    add_column :sections,
               :image_position_x,
               :integer,
               default: 50,
               null: false

    add_column :sections,
               :image_position_y,
               :integer,
               default: 50,
               null: false

    add_column :sections,
               :banner_position_x,
               :integer,
               default: 50,
               null: false

    add_column :sections,
               :banner_position_y,
               :integer,
               default: 50,
               null: false
  end
end
