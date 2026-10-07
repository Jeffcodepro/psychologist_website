# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_07_160000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "contact_requests", force: :cascade do |t|
    t.string "full_name", default: "", null: false
    t.string "phone", default: "", null: false
    t.string "email", default: "", null: false
    t.text "message", default: "", null: false
    t.string "source_path"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "email_delivered_at"
    t.string "email_delivery_error"
    t.string "request_fingerprint"
    t.bigint "tenant_id", null: false
    t.jsonb "answers", default: {}, null: false
    t.jsonb "form_snapshot", default: [], null: false
    t.index ["request_fingerprint", "created_at"], name: "index_contact_requests_on_request_fingerprint_and_created_at"
    t.index ["tenant_id", "email", "created_at"], name: "index_contact_requests_on_site_email_time"
    t.index ["tenant_id"], name: "index_contact_requests_on_tenant_id"
  end

  create_table "pages", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "published", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "published_at"
    t.text "description"
    t.text "description_en"
    t.string "nav_label"
    t.string "nav_label_en"
    t.boolean "show_in_nav", default: true, null: false
    t.integer "position", default: 0, null: false
    t.string "seo_title"
    t.string "seo_title_en"
    t.text "seo_description"
    t.text "seo_description_en"
    t.bigint "tenant_id", null: false
    t.string "content_kind", default: "page", null: false
    t.index ["position"], name: "index_pages_on_position"
    t.index ["tenant_id", "content_kind"], name: "index_pages_on_tenant_id_and_content_kind"
    t.index ["tenant_id", "slug"], name: "index_pages_on_tenant_id_and_slug", unique: true
    t.index ["tenant_id"], name: "index_pages_on_tenant_id"
  end

  create_table "section_items", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.string "title", null: false
    t.text "body"
    t.integer "position", default: 0, null: false
    t.boolean "visible", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title_en"
    t.text "body_en"
    t.integer "image_position_x", default: 50, null: false
    t.integer "image_position_y", default: 50, null: false
    t.decimal "image_zoom", precision: 4, scale: 2, default: "1.0", null: false
    t.string "image_shape", default: "rectangle", null: false
    t.jsonb "media_adjustments", default: {}, null: false
    t.string "item_kind", default: "card", null: false
    t.bigint "linked_page_id"
    t.jsonb "card_settings", default: {}, null: false
    t.jsonb "video_settings", default: {}, null: false
    t.index ["linked_page_id"], name: "index_section_items_on_linked_page_id"
    t.index ["section_id"], name: "index_section_items_on_section_id"
  end

  create_table "section_slides", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.string "role", default: "image", null: false
    t.integer "position", default: 0, null: false
    t.integer "image_position_x", default: 50, null: false
    t.integer "image_position_y", default: 50, null: false
    t.decimal "image_zoom", precision: 4, scale: 2, default: "1.0", null: false
    t.string "image_shape", default: "rounded", null: false
    t.jsonb "media_adjustments", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "video_settings", default: {}, null: false
    t.index ["section_id"], name: "index_section_slides_on_section_id"
  end

  create_table "sections", force: :cascade do |t|
    t.bigint "page_id", null: false
    t.string "section_type", null: false
    t.string "title"
    t.text "body"
    t.integer "position", default: 0, null: false
    t.boolean "visible", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title_en"
    t.text "body_en"
    t.string "publication_state", default: "draft", null: false
    t.string "anchor"
    t.boolean "show_in_nav", default: false, null: false
    t.string "nav_label"
    t.string "nav_label_en"
    t.string "title_font_family", default: "playfair", null: false
    t.string "body_font_family", default: "dm_sans", null: false
    t.integer "title_font_size_desktop", default: 48, null: false
    t.integer "title_font_size_mobile", default: 34, null: false
    t.integer "body_font_size_desktop", default: 18, null: false
    t.integer "body_font_size_mobile", default: 16, null: false
    t.string "text_alignment", default: "left", null: false
    t.string "text_theme", default: "dark", null: false
    t.string "banner_position", default: "center", null: false
    t.integer "banner_overlay", default: 35, null: false
    t.string "content_vertical_position", default: "center", null: false
    t.integer "image_position_x", default: 50, null: false
    t.integer "image_position_y", default: 50, null: false
    t.integer "banner_position_x", default: 50, null: false
    t.integer "banner_position_y", default: 50, null: false
    t.string "cards_orientation", default: "horizontal", null: false
    t.boolean "cards_wrap", default: true, null: false
    t.integer "cards_columns_desktop", default: 3, null: false
    t.integer "cards_columns_tablet", default: 2, null: false
    t.integer "cards_columns_mobile", default: 1, null: false
    t.boolean "cards_autoplay", default: true, null: false
    t.integer "cards_autoplay_seconds", default: 5, null: false
    t.float "banner_zoom", default: 1.0, null: false
    t.float "image_zoom", default: 1.0, null: false
    t.string "image_shape", default: "rounded", null: false
    t.string "media_layout", default: "text_left", null: false
    t.string "media_size", default: "medium", null: false
    t.string "banner_layout", default: "top", null: false
    t.string "title_color"
    t.string "body_color"
    t.string "accent_color"
    t.string "background_color"
    t.string "overlay_color"
    t.jsonb "responsive_settings", default: {}, null: false
    t.string "cards_placement", default: "after", null: false
    t.string "cards_alignment", default: "center", null: false
    t.integer "media_interval_seconds", default: 5, null: false
    t.boolean "use_profile_image", default: false, null: false
    t.jsonb "media_adjustments", default: {}, null: false
    t.string "text_order", default: "title_first", null: false
    t.string "title_alignment"
    t.string "body_alignment"
    t.jsonb "form_fields", default: [], null: false
    t.integer "title_font_weight", default: 500, null: false
    t.string "title_font_style", default: "normal", null: false
    t.decimal "title_line_height", precision: 3, scale: 2, default: "1.2", null: false
    t.decimal "title_letter_spacing", precision: 3, scale: 2, default: "0.0", null: false
    t.integer "body_font_weight", default: 400, null: false
    t.string "body_font_style", default: "normal", null: false
    t.decimal "body_line_height", precision: 3, scale: 2, default: "1.7", null: false
    t.decimal "body_letter_spacing", precision: 3, scale: 2, default: "0.0", null: false
    t.jsonb "action_buttons", default: [], null: false
    t.string "buttons_position", default: "after_text", null: false
    t.string "buttons_alignment", default: "left", null: false
    t.jsonb "layout_settings", default: {}, null: false
    t.uuid "navigation_key", default: -> { "gen_random_uuid()" }, null: false
    t.jsonb "video_settings", default: {}, null: false
    t.index ["page_id", "publication_state", "anchor"], name: "index_sections_on_page_state_anchor", unique: true, where: "(anchor IS NOT NULL)"
    t.index ["page_id", "publication_state", "navigation_key"], name: "index_sections_on_navigation_key", unique: true
    t.index ["page_id", "publication_state", "position"], name: "index_sections_on_page_state_position"
    t.index ["page_id"], name: "index_sections_on_page_id"
  end

  create_table "site_settings", force: :cascade do |t|
    t.string "professional_name", null: false
    t.string "crp"
    t.string "email"
    t.string "phone"
    t.string "whatsapp"
    t.string "instagram"
    t.string "linkedin"
    t.text "footer_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "footer_text_en"
    t.string "facebook"
    t.string "youtube"
    t.string "tiktok"
    t.string "threads"
    t.string "x_twitter"
    t.string "seo_title"
    t.text "seo_description"
    t.string "seo_keywords"
    t.float "logo_zoom", default: 1.0, null: false
    t.integer "logo_position_x", default: 50, null: false
    t.integer "logo_position_y", default: 50, null: false
    t.float "profile_image_zoom", default: 1.0, null: false
    t.integer "profile_image_position_x", default: 50, null: false
    t.integer "profile_image_position_y", default: 50, null: false
    t.boolean "demo_contacts", default: false, null: false
    t.bigint "tenant_id", null: false
    t.jsonb "header_actions", default: [], null: false
    t.jsonb "footer_actions", default: [], null: false
    t.index ["tenant_id"], name: "index_site_settings_on_tenant_id"
    t.index ["tenant_id"], name: "unique_site_setting_per_tenant", unique: true
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "domain"
    t.string "login_digest"
    t.boolean "primary", default: false, null: false
    t.boolean "active", default: true, null: false
    t.string "contact_recipient"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_tenants_on_domain", unique: true, where: "(domain IS NOT NULL)"
    t.index ["login_digest"], name: "index_tenants_on_login_digest", unique: true, where: "(login_digest IS NOT NULL)"
    t.index ["primary"], name: "index_tenants_on_primary", unique: true, where: "(\"primary\" = true)"
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.bigint "tenant_id", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["tenant_id"], name: "index_users_on_tenant_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "contact_requests", "tenants"
  add_foreign_key "pages", "tenants"
  add_foreign_key "section_items", "pages", column: "linked_page_id", on_delete: :nullify
  add_foreign_key "section_items", "sections"
  add_foreign_key "section_slides", "sections"
  add_foreign_key "sections", "pages"
  add_foreign_key "site_settings", "tenants"
  add_foreign_key "users", "tenants"
end
