class CreateSectionItems < ActiveRecord::Migration[7.1]
  def change
    create_table :section_items do |t|
      t.references :section, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body
      t.integer :position, default: 0, null: false
      t.boolean :visible, default: true, null: false

      t.timestamps
    end
  end
end
