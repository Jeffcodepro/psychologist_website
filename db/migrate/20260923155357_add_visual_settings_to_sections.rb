class AddVisualSettingsToSections < ActiveRecord::Migration[7.1]
  def change
    add_column :sections,
               :title_font_family,
               :string,
               default: "playfair",
               null: false

    add_column :sections,
               :body_font_family,
               :string,
               default: "dm_sans",
               null: false

    add_column :sections,
               :title_font_size_desktop,
               :integer,
               default: 48,
               null: false

    add_column :sections,
               :title_font_size_mobile,
               :integer,
               default: 34,
               null: false

    add_column :sections,
               :body_font_size_desktop,
               :integer,
               default: 18,
               null: false

    add_column :sections,
               :body_font_size_mobile,
               :integer,
               default: 16,
               null: false

    add_column :sections,
               :text_alignment,
               :string,
               default: "left",
               null: false

    add_column :sections,
               :text_theme,
               :string,
               default: "dark",
               null: false

    add_column :sections,
               :banner_position,
               :string,
               default: "center",
               null: false

    add_column :sections,
               :banner_overlay,
               :integer,
               default: 35,
               null: false

    add_column :sections,
               :content_vertical_position,
               :string,
               default: "center",
               null: false
  end
end
