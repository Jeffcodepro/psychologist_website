module SeoHelper
  def seo_urls
    @seo_urls ||= SiteUrls.new(current_tenant, request: request)
  end

  def seo_title
    if @page&.home? && @page.seo_title.blank? && (I18n.locale != :en || @page.seo_title_en.blank?)
      @site_setting&.seo_title.presence || @site_setting&.professional_name.presence || @page.name
    else
      @page&.localized_seo_title.presence || @site_setting&.seo_title.presence || @site_setting&.professional_name
    end
  end

  def seo_description
    @page&.localized_seo_description.presence || @site_setting&.seo_description.presence
  end

  def seo_image_url
    attachment = if @site_setting&.seo_image&.attached?
      @site_setting.seo_image
    elsif @site_setting&.logo&.attached?
      @site_setting.logo
    end
    return unless attachment
    return ImageDelivery.cloudinary_url(attachment.blob, width: 1200) if ImageDelivery.cloudinary?(attachment.blob)
    rails_storage_proxy_url(attachment, host: URI(seo_urls.home).host, protocol: URI(seo_urls.home).scheme)
  end

  def seo_structured_data
    name = @site_setting&.professional_name.presence || current_tenant.name
    author = { "@type" => "Person", "name" => name, "url" => seo_urls.home }
    author["sameAs"] = social_profiles(@site_setting).pluck(:url) if social_profiles(@site_setting).any?
    website = { "@type" => "WebSite", "name" => name, "url" => seo_urls.home }
    graph = [website, author]
    if @page&.editorial? && @page.published?
      graph << {
        "@type" => "BlogPosting", "headline" => seo_title, "description" => seo_description,
        "url" => seo_urls.page(@page), "author" => author,
        "datePublished" => @page.published_at&.iso8601, "dateModified" => @page.updated_at.iso8601,
        "inLanguage" => I18n.locale.to_s, "image" => seo_image_url
      }.compact
    end
    { "@context" => "https://schema.org", "@graph" => graph }
  end
end
