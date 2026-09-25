class AddEnglishContentToSections < ActiveRecord::Migration[7.1]
  def change
    add_column :sections, :title_en, :string
    add_column :sections, :body_en, :text

    add_column :section_items, :title_en, :string
    add_column :section_items, :body_en, :text

    add_column :site_settings, :footer_text_en, :text
  end
end
