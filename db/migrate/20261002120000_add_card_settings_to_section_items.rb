class AddCardSettingsToSectionItems < ActiveRecord::Migration[8.1]
  def change
    add_column :section_items, :card_settings, :jsonb, default: {}, null: false
  end
end
