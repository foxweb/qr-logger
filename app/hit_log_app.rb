# frozen_string_literal: true

require 'json'

# Main application class
class HitLogApp
  def call(env)
    # Health check endpoint (before host validation)
    return health_check if env['PATH_INFO'] == '/health'

    # Admin panel (before host validation for flexibility)
    return Admin.call(env) if env['PATH_INFO'] =~ %r{^/admin}

    # Validate host
    unless HOSTNAMES.include?(env['HTTP_HOST'])
      LOGGER.warn "Blocked request from invalid host: #{env['HTTP_HOST']}"
      return [444, {}, []]
    end

    case [env['REQUEST_METHOD'], env['PATH_INFO']]
    when ['GET', '/y'], ['GET', '/youtube']
      hit!(env)
    when ['GET', '/test']
      return [200, { 'content-type' => 'text/plain' }, [env['HTTP_USER_AGENT'], "\n", env['REMOTE_ADDR']]]
    end
    [302, { 'location' => REDIRECT_TO }, []]
  rescue StandardError => e
    LOGGER.error "Unhandled error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    [500, { 'content-type' => 'text/plain' }, ["Internal Server Error\n"]]
  end

  private

  def health_check
    result = Database.health_check
    status = result[:status] == 'ok' ? 200 : 503
    body = {
      status: result[:status] == 'ok' ? 'healthy' : 'unhealthy',
      version: VERSION,
      database: result[:database],
      timestamp: Time.now.iso8601
    }

    [status, { 'content-type' => 'application/json' }, [body.to_json]]
  end

  def hit!(env)
    ip = env['HTTP_X_REAL_IP'] || env['HTTP_X_FORWARDED_FOR']&.split(',')&.first&.strip || env['REMOTE_ADDR']
    user_agent = env['HTTP_USER_AGENT'] || 'Unknown'
    referer = env['HTTP_REFERER'] || ''
    host = env['HTTP_HOST']

    Database.log_hit(ip: ip, user_agent: user_agent, referer: referer, host: host)
  end
end
