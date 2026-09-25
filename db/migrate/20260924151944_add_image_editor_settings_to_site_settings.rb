class AddImageEditorSettingsToSiteSettings < ActiveRecord::Migration[7.1]
  def change
    # ==================================================
    # LOGO
    # ==================================================

    add_column :site_settings,
               :logo_zoom,
               :float,
               default: 1.0,
               null: false

    add_column :site_settings,
               :logo_position_x,
               :integer,
               default: 50,
               null: false

    add_column :site_settings,
               :logo_position_y,
               :integer,
               default: 50,
               null: false


    # ==================================================
    # PROFILE IMAGE
    # ==================================================

    add_column :site_settings,
               :profile_image_zoom,
               :float,
               default: 1.0,
               null: false

    add_column :site_settings,
               :profile_image_position_x,
               :integer,
               default: 50,
               null: false

    add_column :site_settings,
               :profile_image_position_y,
               :integer,
               default: 50,
               null: false
  end
end
