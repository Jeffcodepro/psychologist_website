module FormattedContentsHelper
  def formatted_content(value)
    FormattedContent.render(value)
  end
end
