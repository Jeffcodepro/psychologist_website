class AddCmsFieldsToPages < ActiveRecord::Migration[7.1]
  def change
    add_column :pages, :description, :text
    add_column :pages, :description_en, :text

    add_column :pages, :nav_label, :string
    add_column :pages, :nav_label_en, :string
    add_column :pages, :show_in_nav, :boolean, default: true, null: false
    add_column :pages, :position, :integer, default: 0, null: false

    add_column :pages, :seo_title, :string
    add_column :pages, :seo_title_en, :string
    add_column :pages, :seo_description, :text
    add_column :pages, :seo_description_en, :text

    add_index :pages, :position
  end
end
