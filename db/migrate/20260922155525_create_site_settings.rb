class CreateSiteSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :site_settings do |t|
      t.string :professional_name, null: false
      t.string :crp
      t.string :email
      t.string :phone
      t.string :whatsapp
      t.string :instagram
      t.string :linkedin
      t.text :footer_text

      t.timestamps
    end
  end
end
