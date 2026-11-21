# frozen_string_literal: true

# Answers health checks at /-/health before any other middleware, without the
# database, so a container is ready as soon as Redmine has booted, including
# before the first installation creates its tables.
class WodbyHealthCheck
  PATH = '/-/health'

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env['PATH_INFO'] == PATH

    [200, {'content-type' => 'text/plain', 'cache-control' => 'no-store'}, ['OK']]
  end
end

Rails.application.config.middleware.insert_before 0, WodbyHealthCheck
