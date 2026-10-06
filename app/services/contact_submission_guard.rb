# Database checks and saving share one short lock, including across Swarm replicas.
# SMTP delivery deliberately happens after this transaction has finished.
class ContactSubmissionGuard
  COOLDOWN = 10.minutes
  IP_WINDOW = 1.hour
  IP_LIMIT = 5
  Result = Struct.new(:accepted?, :retry_after, keyword_init: true)

  def self.fingerprint(ip)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, ip.to_s)
  end

  def self.receipt_retry_after(session, tenant_id)
    sent_at = session.fetch(:contact_receipts, {}).fetch(tenant_id.to_s, 0).to_i
    [sent_at + COOLDOWN.to_i - Time.current.to_i, 0].max
  end

  def self.remember_submission(session, tenant_id)
    now = Time.current.to_i
    receipts = session.fetch(:contact_receipts, {}).select { |_, at| at.to_i > now - COOLDOWN.to_i }
    # Keep the encrypted session cookie small on installations with shared domains.
    receipts = receipts.sort_by { |_, at| at.to_i }.last(19).to_h
    session[:contact_receipts] = receipts.merge(tenant_id.to_s => now)
  end

  def initialize(contact_request:, session:)
    @contact = contact_request
    @tenant = contact_request.tenant
    @session = session
  end

  def save
    result = @tenant.with_lock do
      wait = retry_after
      if wait.positive?
        Result.new(accepted?: false, retry_after: wait)
      else
        @contact.save!
        Result.new(accepted?: true, retry_after: 0)
      end
    end
    self.class.remember_submission(@session, @tenant.id) if result.accepted?
    result
  end

  private

  def retry_after
    now = Time.current
    same_ip = @tenant.contact_requests.where(request_fingerprint: @contact.request_fingerprint)
    latest_ip = same_ip.where(created_at: (now - COOLDOWN)..).maximum(:created_at)
    latest_email = if @contact.email.present?
      @tenant.contact_requests.where(email: @contact.email, created_at: (now - COOLDOWN)..).maximum(:created_at)
    end
    # The fifth most recent submission must expire before another one is accepted.
    hourly_boundary = same_ip.where(created_at: (now - IP_WINDOW)..)
      .order(created_at: :desc).offset(IP_LIMIT - 1).pick(:created_at)
    waits = [self.class.receipt_retry_after(@session, @tenant.id)]
    [latest_ip, latest_email].compact.each { |at| waits << (at + COOLDOWN - now).ceil }
    waits << (hourly_boundary + IP_WINDOW - now).ceil if hourly_boundary
    waits.max.clamp(0, IP_WINDOW.to_i)
  end
end
