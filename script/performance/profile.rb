abort "Only the performance environment is allowed." unless Rails.env == "performance"
require "action_dispatch/testing/integration"
require "json"
session = ActionDispatch::Integration::Session.new(Rails.application)
session.host!("rosemary.performance.test")
session.get("/") # Compile templates/assets before measuring.
queries = []
subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
  queries << payload[:sql] unless payload[:cached] || payload[:name] == "SCHEMA" || payload[:sql].match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/)
end
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
session.get("/")
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
ActiveSupport::Notifications.unsubscribe(subscriber)
puts JSON.pretty_generate(status: session.response.status, sql_queries: queries.size, elapsed_ms: (elapsed * 1000).round(1), response_bytes: session.response.body.bytesize, sql_groups: queries.group_by { |sql| sql[/FROM "([^"]+)"/, 1] || "other" }.transform_values(&:size))
