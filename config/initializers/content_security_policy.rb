Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self
    policy.style_src :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src :self, :data, "https://fonts.gstatic.com"
    policy.img_src :self, :data, :blob, "https://res.cloudinary.com", "https://i.ytimg.com"
    policy.connect_src :self
    policy.media_src :self, :blob, "https://res.cloudinary.com"
    policy.frame_src :self, "https://www.youtube-nocookie.com"
    policy.frame_ancestors :self
    policy.object_src :none
    policy.base_uri :self
    policy.form_action :self
  end
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
