class FormattedContent
  TAGS = %w[p br strong em b i u del s h2 h3 h4 ul ol li blockquote a code pre hr].freeze

  class Renderer < Redcarpet::Render::HTML
    def header(text, level)
      level = level.clamp(2, 4)
      "<h#{level}>#{text}</h#{level}>"
    end
  end

  def self.render(value)
    renderer = Renderer.new(hard_wrap: true, no_images: true, safe_links_only: true)
    html = Redcarpet::Markdown.new(renderer, no_intra_emphasis: true,
      strikethrough: true, space_after_headers: true, disable_indented_code_blocks: true).render(value.to_s)
    # Also sanitize raw HTML pasted into older text fields and Markdown links.
    ActionController::Base.helpers.sanitize(html, tags: TAGS, attributes: %w[href title])
  end

  def self.plain(value)
    ActionView::Base.full_sanitizer.sanitize(render(value)).squish
  end
end
