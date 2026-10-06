class AddLayoutSettingsToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :layout_settings, :jsonb, default: {}, null: false
  end
end
