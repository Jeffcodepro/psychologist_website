class AddCardLayoutSettingsToSections < ActiveRecord::Migration[7.1]
  def change
    add_column :sections,
               :cards_orientation,
               :string,
               default: "horizontal",
               null: false

    add_column :sections,
               :cards_wrap,
               :boolean,
               default: true,
               null: false

    add_column :sections,
               :cards_columns_desktop,
               :integer,
               default: 3,
               null: false

    add_column :sections,
               :cards_columns_tablet,
               :integer,
               default: 2,
               null: false

    add_column :sections,
               :cards_columns_mobile,
               :integer,
               default: 1,
               null: false

    add_column :sections,
               :cards_autoplay,
               :boolean,
               default: true,
               null: false

    add_column :sections,
               :cards_autoplay_seconds,
               :integer,
               default: 5,
               null: false
  end
end
