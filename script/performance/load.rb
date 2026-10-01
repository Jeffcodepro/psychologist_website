#!/usr/bin/env ruby
# Deliberately targets loopback only. No production URL option.
require "net/http"
require "json"
require "fileutils"
require "time"
port = Integer(ENV.fetch("PERFORMANCE_PORT", "3101"))
duration = Integer(ENV.fetch("DURATION", "10"))
levels = ENV.fetch("CONCURRENCY", "1,10,25,50").split(",").map { |value| Integer(value) }
abort "Use durations of 1..60 seconds and concurrency of 1..100." unless (1..60).cover?(duration) && levels.all? { |value| (1..100).cover?(value) }
output = ARGV.fetch(0, "tmp/performance/results.json")
clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
percentile = ->(values, pct) { values.sort.fetch([(values.length * pct).ceil - 1, 0].max, 0).round(1) }
%w[rosemary thiago].each do |name|
  Net::HTTP.start("127.0.0.1", port, nil, open_timeout: 3, read_timeout: 30) do |http|
    response = http.get("/", "Host" => "#{name}.performance.test")
    abort "Warmup failed for #{name}: #{response.code}" unless response.code == "200" && response.body.include?("#{name.upcase}_PERFORMANCE_PAGE")
  end
end
results = []
levels.each do |concurrency|
  started = clock.call
  deadline = started + duration
  rows = Queue.new
  workers = concurrency.times.map do |worker|
    Thread.new do
      name = worker.even? ? "rosemary" : "thiago"
      http = Net::HTTP.new("127.0.0.1", port, nil)
      http.open_timeout = 3
      http.read_timeout = 10
      http.write_timeout = 3
      http.max_retries = 0
      begin
        http.start
        while clock.call < deadline
          before = clock.call
          response = http.get("/", "Host" => "#{name}.performance.test", "Connection" => "keep-alive")
          ok = response.code == "200" && response.body.include?("#{name.upcase}_PERFORMANCE_PAGE") && response.body.scan("data-card-id=").size == 36 && response.body.scan("data-section-id=").size == 12 && !response.body.include?("#{name == 'rosemary' ? 'THIAGO' : 'ROSEMARY'}_PERFORMANCE_PAGE")
          rows << { ms: (clock.call - before) * 1000, status: response.code, ok: ok, bytes: response.body.bytesize }
        end
      rescue StandardError => error
        rows << { ms: 10_000, status: error.class.name, ok: false, bytes: 0 }
      ensure
        http.finish if http.started?
      end
    end
  end
  workers.each(&:join)
  elapsed = clock.call - started
  data = []
  data << rows.pop until rows.empty?
  timings = data.map { |row| row[:ms] }
  result = { concurrency: concurrency, requested_seconds: duration, elapsed_seconds: elapsed.round(2), requests: data.size, errors: data.count { |row| !row[:ok] }, rps: (data.size / elapsed).round(2), p50_ms: percentile.call(timings, 0.50), p95_ms: percentile.call(timings, 0.95), p99_ms: percentile.call(timings, 0.99), statuses: data.group_by { |row| row[:status] }.transform_values(&:size), average_html_bytes: (data.sum { |row| row[:bytes] } / [data.size, 1].max) }
  results << result
  puts JSON.generate(result)
  STDOUT.flush
end
FileUtils.mkdir_p(File.dirname(output))
File.write(output, JSON.pretty_generate(measured_at: Time.now.utc.iso8601, ruby: RUBY_DESCRIPTION, mode: "closed-loop, HTML only, two synthetic domains, no external services", stages: results))
exit(results.any? { |result| result[:errors].positive? } ? 1 : 0)
