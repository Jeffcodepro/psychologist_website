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
    state = cms_preview? ? 'draft' : 'published'
    item.linked_page.sections.where(publication_state: state).visible.ordered.detect { |section| section.localized_body.present? }&.localized_body
  end

  def card_destination(item)
    page = item.linked_page
    return unless page && page.tenant_id == current_tenant.id
    return admin_page_preview_path(page, locale: I18n.locale) if cms_preview?
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

  def contact_destination(locale: I18n.locale)
    if cms_preview?
      page = current_tenant.contact_page
      page ? admin_page_preview_path(page, locale: locale) : admin_pages_path(locale: locale)
    else
      contact_path(locale: locale)
    end
  end

  def cms_home_preview_path
    page = current_tenant.pages.find_by(slug: "home") || current_tenant.pages.ordered.first
    page ? admin_page_preview_path(page) : admin_pages_path
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
    when 'anchor' then "##{value.delete_prefix('#')}"
    when 'whatsapp' then "https://wa.me/#{value.gsub(/\D/, '')}"
    when 'phone' then "tel:#{value.gsub(/[^\d+]/, '')}"
    when 'email' then "mailto:#{value}"
    when 'url' then value if ActionButtonSchema.valid_destination?('url', value, current_tenant)
    end
  end

end
