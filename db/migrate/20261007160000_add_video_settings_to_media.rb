class AddVideoSettingsToMedia < ActiveRecord::Migration[8.1]
  def change
    %i[sections section_items section_slides].each do |table|
      add_column table, :video_settings, :jsonb, default: {}, null: false
    end
  end
end
