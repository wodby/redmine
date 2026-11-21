# frozen_string_literal: true

# Puma's settings, read from environment variables.

max_threads = Integer(ENV.fetch('RAILS_MAX_THREADS', 5))
threads Integer(ENV.fetch('RAILS_MIN_THREADS', max_threads)), max_threads

port Integer(ENV.fetch('PORT', 3000)), '0.0.0.0'
environment ENV.fetch('RAILS_ENV', 'production')
pidfile ENV.fetch('PIDFILE', 'tmp/pids/server.pid')

# Keep idle connections from the gateway open longer than its own idle timeout
# would close them from Puma's side.
persistent_timeout Integer(ENV.fetch('PUMA_PERSISTENT_TIMEOUT', 75))

# 0 runs one process; more forks workers that share the loaded application.
workers_count = Integer(ENV.fetch('WEB_CONCURRENCY', 0))
if workers_count.positive?
  workers workers_count
  preload_app!
  worker_timeout Integer(ENV.fetch('PUMA_WORKER_TIMEOUT', 60))
end
