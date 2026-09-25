class Admin::SiteSettingsController < Admin::BaseController
  before_action :set_site_setting

  # ==================================================
  # EDIT
  # ==================================================

  def edit
  end

  # ==================================================
  # UPDATE
  # ==================================================

  def update
    if @site_setting.update(
      site_setting_params
    )

      redirect_to(
        edit_admin_site_setting_path,
        notice:
          "Configurações atualizadas com sucesso."
      )

    else

      render :edit,
             status: :unprocessable_entity

    end
  end

  private

  # ==================================================
  # SETTINGS
  # ==================================================

  def set_site_setting
    @site_setting =
      SiteSetting.first_or_initialize

    @site_setting.professional_name ||=
      "Rosemary Dias"
  end

  # ==================================================
  # PARAMS
  # ==================================================

  def site_setting_params
    params
      .require(:site_setting)
      .permit(
        # --------------------------------------------
        # PROFESSIONAL
        # --------------------------------------------

        :professional_name,
        :crp,

        # --------------------------------------------
        # CONTACT
        # --------------------------------------------

        :demo_contacts,
        :email,
        :phone,
        :whatsapp,

        # --------------------------------------------
        # SOCIAL
        # --------------------------------------------

        :instagram,
        :linkedin,
        :facebook,
        :youtube,
        :tiktok,
        :threads,
        :x_twitter,

        # --------------------------------------------
        # FOOTER
        # --------------------------------------------

        :footer_text,
        :footer_text_en,

        # --------------------------------------------
        # ASSETS
        # --------------------------------------------

        :logo,
        :profile_image,
        :seo_image,

        # --------------------------------------------
        # LOGO EDITOR
        # --------------------------------------------

        :logo_zoom,
        :logo_position_x,
        :logo_position_y,

        # --------------------------------------------
        # PROFILE EDITOR
        # --------------------------------------------

        :profile_image_zoom,
        :profile_image_position_x,
        :profile_image_position_y,

        # --------------------------------------------
        # SEO
        # --------------------------------------------

        :seo_title,
        :seo_description,
        :seo_keywords
      )
  end
end
