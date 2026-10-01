class LanguagePreferencesController < PublicController
  def update
    response.headers["Cache-Control"] = "no-store, private"
    locale = supported_locale(params[:language])
    return head :unprocessable_entity unless locale

    remember_locale(locale)
    redirect_to safe_return_path || root_path, status: :see_other
  end

  private

  def safe_return_path
    candidate = params[:return_to]
    return unless candidate.is_a?(String) && candidate.start_with?("/")
    return if candidate.start_with?("//") || candidate.match?(/[\\\x00-\x20]/)

    uri = URI.parse(candidate)
    return if uri.host || uri.scheme
    route = Rails.application.routes.recognize_path(uri.path, method: :get)
    return unless %w[pages contacts].include?(route[:controller])
    return unless route[:site_slug].to_s == params[:site_slug].to_s

    query = URI.decode_www_form(uri.query.to_s).reject { |key, _| key == "locale" || key.start_with?("locale[") }
    uri.query = query.empty? ? nil : URI.encode_www_form(query)
    uri.to_s
  rescue URI::InvalidURIError, ActionController::RoutingError, ArgumentError
    nil
  end
end
