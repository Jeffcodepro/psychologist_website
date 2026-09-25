class AddSeoAndSocialFieldsToSiteSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :site_settings,
               :facebook,
               :string

    add_column :site_settings,
               :youtube,
               :string

    add_column :site_settings,
               :tiktok,
               :string

    add_column :site_settings,
               :threads,
               :string

    add_column :site_settings,
               :x_twitter,
               :string

    add_column :site_settings,
               :seo_title,
               :string

    add_column :site_settings,
               :seo_description,
               :text

    add_column :site_settings,
               :seo_keywords,
               :string
  end
end
