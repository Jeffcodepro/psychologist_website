# Accept a video link, never user-supplied iframe markup or arbitrary embed hosts.
class YoutubeVideo
  ID = /\A[a-zA-Z0-9_-]{11}\z/
  HOSTS = %w[youtube.com www.youtube.com m.youtube.com youtube-nocookie.com www.youtube-nocookie.com].freeze

  def self.id(url)
    uri = URI.parse(url.to_s.strip)
    return unless %w[http https].include?(uri.scheme) && uri.userinfo.nil? && uri.port == (uri.scheme == "https" ? 443 : 80)
    candidate = if %w[youtu.be www.youtu.be].include?(uri.host)
      uri.path.delete_prefix("/")
    elsif HOSTS.include?(uri.host)
      if uri.path == "/watch"
        URI.decode_www_form(uri.query.to_s).to_h["v"]
      elsif uri.path.match?(%r{\A/(embed|shorts|live)/})
        uri.path.split("/")[2]
      end
    end
    candidate if candidate.to_s.match?(ID)
  rescue URI::InvalidURIError, ArgumentError
    nil
  end
end
