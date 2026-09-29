class AddEditableActionButtons < ActiveRecord::Migration[7.1]
  def up
    add_column :sections, :action_buttons, :jsonb, default: [], null: false
    add_column :sections, :buttons_position, :string, default: "after_text", null: false
    add_column :sections, :buttons_alignment, :string, default: "left", null: false
    add_column :site_settings, :header_actions, :jsonb, default: [], null: false
    add_column :site_settings, :footer_actions, :jsonb, default: [], null: false
    button = [{ label: "Agende agora", label_en: "Book a conversation", action: "contact", value: "", style: "primary" }].to_json
    # Preserve existing visible calls to action as editable content, not defaults
    # that reappear when the owner removes them.
    execute "UPDATE sections SET action_buttons = #{connection.quote(button)}::jsonb WHERE section_type IN ('hero', 'cta')"
    execute "UPDATE site_settings SET header_actions = #{connection.quote(button)}::jsonb, footer_actions = #{connection.quote(button)}::jsonb"
  end

  def down
    remove_column :sections, :action_buttons
    remove_column :sections, :buttons_position
    remove_column :sections, :buttons_alignment
    remove_column :site_settings, :header_actions
    remove_column :site_settings, :footer_actions
  end
end
