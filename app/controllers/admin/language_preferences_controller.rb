class Admin::LanguagePreferencesController < Admin::BaseController
  def update
    language = params[:language]
    return head :unprocessable_entity unless language.is_a?(String) && I18n.available_locales.map(&:to_s).include?(language)

    session[:admin_preview_locale] = language
    respond_to do |format|
      format.json { render json: { language: language } }
      format.html { redirect_to preview_return_path, status: :see_other }
    end
  end

  private

  def preview_return_path
    candidate = params[:return_to].to_s
    candidate.match?(%r{\A/admin/pages/[0-9]+/preview\z}) ? candidate : admin_root_path
  end
end
