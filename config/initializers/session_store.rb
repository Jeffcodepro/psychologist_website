Rails.application.config.session_store :cookie_store,
  key: "_rosemary_cms_session", httponly: true, same_site: :lax,
  secure: Rails.env.production?, expire_after: 8.hours
