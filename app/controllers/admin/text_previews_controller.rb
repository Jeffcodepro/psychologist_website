class Admin::TextPreviewsController < Admin::BaseController
  def create
    text = params[:text].to_s
    return head :content_too_large if text.bytesize > 200_000
    render json: { html: FormattedContent.render(text) }
  end
end
