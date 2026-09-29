class IsolateTenantsAndCustomizeContactForms < ActiveRecord::Migration[7.1]
  def up
    create_table :tenants do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :domain
      t.string :login_digest
      t.boolean :primary, default: false, null: false
      t.boolean :active, default: true, null: false
      t.string :contact_recipient
      t.timestamps
    end
    add_index :tenants, :slug, unique: true
    add_index :tenants, :domain, unique: true, where: "domain IS NOT NULL"
    add_index :tenants, :login_digest, unique: true, where: "login_digest IS NOT NULL"
    add_index :tenants, :primary, unique: true, where: "\"primary\" = TRUE"

    execute "INSERT INTO tenants (name, slug, \"primary\", created_at, updated_at) VALUES ('Rosemary Dias', 'rosemary', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    tenant_id = select_value("SELECT id FROM tenants WHERE \"primary\" = TRUE")
    %i[users pages site_settings contact_requests].each do |table|
      add_reference table, :tenant, foreign_key: true
      execute "UPDATE #{table} SET tenant_id = #{Integer(tenant_id)}"
      change_column_null table, :tenant_id, false
    end
    remove_index :pages, :slug
    add_index :pages, [:tenant_id, :slug], unique: true
    add_index :site_settings, :tenant_id, unique: true, name: "unique_site_setting_per_tenant"

    add_column :sections, :form_fields, :jsonb, null: false, default: []
    add_column :contact_requests, :answers, :jsonb, null: false, default: {}
    add_column :contact_requests, :form_snapshot, :jsonb, null: false, default: []
    %i[full_name phone email message].each { |field| change_column_default :contact_requests, field, "" }
    %i[title body].each do |role|
      add_column :sections, "#{role}_font_weight", :integer, default: role == :title ? 500 : 400, null: false
      add_column :sections, "#{role}_font_style", :string, default: "normal", null: false
      add_column :sections, "#{role}_line_height", :decimal, precision: 3, scale: 2, default: role == :title ? 1.2 : 1.7, null: false
      add_column :sections, "#{role}_letter_spacing", :decimal, precision: 3, scale: 2, default: 0, null: false
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Reunir clientes apagaria a separação de dados."
  end
end
