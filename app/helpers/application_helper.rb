module ApplicationHelper
  SOCIAL_NETWORKS = [
    [:instagram, "Instagram", "instagram"],
    [:linkedin, "LinkedIn", "linkedin-in"],
    [:facebook, "Facebook", "facebook-f"],
    [:youtube, "YouTube", "youtube"],
    [:tiktok, "TikTok", "tiktok"],
    [:threads, "Threads", "threads"],
    [:x_twitter, "X / Twitter", "x-twitter"]
  ].map(&:freeze).freeze

  def social_profiles(settings)
    return [] unless settings

    SOCIAL_NETWORKS.filter_map do |field, label, icon|
      url = settings.public_send(field).presence
      { label: label, icon: icon, url: url } if url
    end
  end

  def card_preview_body(item, linked:)
    return item.localized_body if item.localized_body.present?
    return unless linked && item.linked_page&.editorial?
    sections = cms_preview? ? item.linked_page.sections.draft.visible.ordered : item.linked_page.published_sections
    sections.detect { |section| section.localized_body.present? }&.localized_body
  end

  def card_destination(item)
    page = item.linked_page
    return unless page && page.tenant_id == current_tenant.id
    return admin_page_preview_path(page) if cms_preview?
    return unless page.published?
    page.home? ? root_path : public_page_path(slug: page.slug)
  end

  def content_library_path(page)
    page.editorial? ? admin_articles_path : admin_pages_path
  end

  def content_library_label(page)
    page.editorial? ? 'Blog e textos' : 'Páginas'
  end

  def cms_preview?
    controller_path.start_with?("admin/")
  end

  def language_return_path
    query = request.query_parameters.except("locale").to_query
    request.path + (query.present? ? "?#{query}" : "")
  end

  def contact_destination
    if cms_preview?
      page = current_tenant.contact_page
      page ? admin_page_preview_path(page) : admin_pages_path
    else
      contact_path
    end
  end

  def cms_home_preview_path
    page = current_tenant.pages.find_by(slug: "home") || current_tenant.pages.ordered.first
    page ? admin_page_preview_path(page) : admin_pages_path
  end
  def button_destination_sections
    @button_destination_sections ||= current_tenant.pages.ordered.includes(:sections).flat_map do |page|
      page.sections.select { |section| section.draft? && section.visible? }.sort_by { |section| [section.position || 0, section.id] }.map do |section|
        published = page.sections.any? { |candidate| candidate.published? && candidate.navigation_key == section.navigation_key }
        ["#{page.name} · #{section.title.presence || section.editor_type_label}#{' (publique para ativar)' unless published}", section.navigation_key]
      end
    end
  end

  def configured_button_style(button)
    return unless button['style'] == 'custom' && ActionButtonSchema.valid_appearance?(button)
    "--button-background: #{button['background_color']}; --button-text: #{button['text_color']}"
  end

  def configured_button_path(button)
    value = button['value'].to_s
    case button['action']
    when 'contact' then contact_destination if current_tenant.contact_page && (cms_preview? || current_tenant.contact_page.published?)
    when 'page'
      pages = cms_preview? ? current_tenant.pages : current_tenant.pages.published
      page = pages.find_by(id: value)
      return unless page
      cms_preview? ? admin_page_preview_path(page) : (page.home? ? root_path : public_page_path(slug: page.slug))
    when 'section'
      sections = cms_preview? ? current_tenant.sections.draft.visible : current_tenant.sections.published.visible.joins(:page).where(pages: { published: true })
      target = sections.find_by(navigation_key: value)
      return unless target
      if cms_preview?
        @page&.id == target.page_id ? "##{target.navigation_anchor}" : admin_page_preview_path(target.page, focus: target.navigation_key)
      else
        target.page.home? ? root_path(anchor: target.navigation_anchor) : public_page_path(slug: target.page.slug, anchor: target.navigation_anchor)
      end
    when 'anchor' then "##{value.delete_prefix('#')}"
    when 'whatsapp' then "https://wa.me/#{value.gsub(/\D/, '')}"
    when 'phone' then "tel:#{value.gsub(/[^\d+]/, '')}"
    when 'email' then "mailto:#{value}"
    when 'url' then value if ActionButtonSchema.valid_destination?('url', value, current_tenant)
    end
  end

end
