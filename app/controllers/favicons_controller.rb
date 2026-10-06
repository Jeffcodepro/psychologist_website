class FaviconsController < PublicController
  # Icons contain only the site's public logo and are independent of login/language.
  skip_before_action :keep_admin_in_cms, :prevent_shared_language_caching
  skip_around_action :published_snapshot

  def show
    logo = @site_setting&.logo
    return head :not_found unless logo&.attached? && logo.variable?

    expires_in 0, public: true, must_revalidate: true
    return unless stale?(etag: [logo.blob, "favicon-png-192-v1"], public: true)

    icon = logo.variant(resize_and_pad: [192, 192], format: :png).processed
    send_data icon.download, type: "image/png", disposition: "inline", filename: "favicon.png"
  end
end
