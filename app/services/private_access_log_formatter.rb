require "delegate"

class PrivateAccessLogFormatter < SimpleDelegator
  def call(severity, timestamp, progname, message)
    safe_message = message.to_s.gsub(%r{/admin/access/[A-Za-z0-9_-]{32,100}}, "/admin/access/[FILTERED]")
    __getobj__.call(severity, timestamp, progname, safe_message)
  end
end
