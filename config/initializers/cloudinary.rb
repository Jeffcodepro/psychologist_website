# CLOUDINARY_URL is supplied through .env locally or a Docker secret in production.
Cloudinary.config { |config| config.secure = true }
if ENV.fetch("ACTIVE_STORAGE_SERVICE", "local") == "cloudinary"
  unless [Cloudinary.config.cloud_name, Cloudinary.config.api_key, Cloudinary.config.api_secret].all?(&:present?)
    raise "Configure CLOUDINARY_URL antes de ativar ACTIVE_STORAGE_SERVICE=cloudinary."
  end
end
