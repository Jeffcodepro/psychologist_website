class Admin::TranslationsController < Admin::BaseController
  def create
    translation = TranslationService.new(
      title: translation_params[:title],
      body: translation_params[:body]
    ).call

    render json: translation
  rescue StandardError => e
    render json: {
      error: e.message
    }, status: :unprocessable_entity
  end

  private

  def translation_params
    params.require(:translation).permit(
      :title,
      :body
    )
  end
end
