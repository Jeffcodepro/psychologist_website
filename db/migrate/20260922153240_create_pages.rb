class CreatePages < ActiveRecord::Migration[7.1]
  def change
    create_table :pages do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :published, default: false, null: false

      t.timestamps
    end

    add_index :pages, :slug, unique: true
  end
end
