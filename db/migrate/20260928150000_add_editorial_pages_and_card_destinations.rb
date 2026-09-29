class AddEditorialPagesAndCardDestinations < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :content_kind, :string, default: 'page', null: false
    add_index :pages, [:tenant_id, :content_kind]
    add_reference :section_items, :linked_page, foreign_key: { to_table: :pages, on_delete: :nullify }
  end
end
