# frozen_string_literal: true

require 'json'
require_relative 'telegram_notify'

# Main application class
class HitLogApp
  def call(env)
    # Health check endpoint (before host validation)
    return health_check if env['PATH_INFO'] == '/health'

    # Admin panel (before host validation for flexibility)
    return Admin.call(env) if env['PATH_INFO'] == '/admin' || env['PATH_INFO'].start_with?('/admin/')

    # Validate host
    unless HOSTNAMES.include?(env['HTTP_HOST'])
      LOGGER.warn "Blocked request from invalid host: #{env['HTTP_HOST']}"
      return [444, {}, []]
    end

    case [env['REQUEST_METHOD'], env['PATH_INFO']]
    when ['GET', '/y'], ['GET', '/youtube']
      hit!(env)
    when ['GET', '/test']
      return test_json(env)
    end
    [302, { 'location' => REDIRECT_TO }, []]
  rescue StandardError => e
    LOGGER.error "Unhandled error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    [500, { 'content-type' => 'text/plain' }, ["Internal Server Error\n"]]
  end

  private

  def test_json(env)
    ip = request_ip(env)
    body = {
      ip: ip,
      host: env['HTTP_HOST'],
      method: env['REQUEST_METHOD'],
      path: env['PATH_INFO'],
      query: env['QUERY_STRING'],
      user_agent: env['HTTP_USER_AGENT'],
      referer: env['HTTP_REFERER']
    }.to_json

    [200, { 'content-type' => 'application/json; charset=utf-8' }, [body]]
  end

  def request_ip(env)
    env['HTTP_X_REAL_IP'] ||
      env['HTTP_X_FORWARDED_FOR']&.split(',')&.first&.strip ||
      env['REMOTE_ADDR']
  end

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
    data = hit_from_env(env)
    ok = Database.log_hit(**data.slice(:ip, :user_agent, :referer, :host))
    TelegramNotify.notify_hit_async(**data) if ok
  end

  # Normalized hit fields from Rack env (for DB + Telegram).
  def hit_from_env(env)
    raw_user_agent = env['HTTP_USER_AGENT'] || 'Unknown'
    raw_referer = env['HTTP_REFERER'] || ''

    {
      ip: request_ip(env),
      user_agent: raw_user_agent.length > 500 ? raw_user_agent[0...500] : raw_user_agent,
      referer: raw_referer.length > 500 ? raw_referer[0...500] : raw_referer,
      host: env['HTTP_HOST'],
      url: request_url(env)
    }
  end

  def request_url(env)
    host = env['HTTP_HOST'].to_s
    path = "#{env['SCRIPT_NAME']}#{env['PATH_INFO']}"
    qs = env['QUERY_STRING'].to_s
    "https://#{host}#{qs.empty? ? path : "#{path}?#{qs}"}"
  end
end
