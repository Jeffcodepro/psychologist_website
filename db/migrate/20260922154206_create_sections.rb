class CreateSections < ActiveRecord::Migration[7.1]
  def change
    create_table :sections do |t|
      t.references :page, null: false, foreign_key: true
      t.string :section_type, null: false
      t.string :title
      t.text :body
      t.integer :position, default: 0, null: false
      t.boolean :visible, default: true, null: false

      t.timestamps
    end
  end
end
