# frozen_string_literal: true

require 'rack'
require 'sequel'
require 'dotenv/load'
require 'active_support'
require 'active_support/isolated_execution_state'
require 'active_support/cache'
require 'rack/attack'
require 'logger'
require 'json'

# Version
VERSION = File.read(File.expand_path('../VERSION', __FILE__)).strip.freeze

# Logging
LOGGER = Logger.new($stdout)
LOGGER.level = ENV.fetch('LOG_LEVEL', 'INFO')
LOGGER.formatter = proc do |severity, datetime, _progname, msg|
  "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
end

# Configuration from ENV
HOSTNAMES = ENV.fetch('ALLOWED_HOSTS').split(',').map(&:strip).freeze
REDIRECT_TO = ENV.fetch('REDIRECT_URL')
DB_URL = ENV.fetch('DATABASE_URL')

# Database connection with error handling
begin
  DB = Sequel.connect(DB_URL)
  DB.extension :pg_inet
  LOGGER.info "QR Logger v#{VERSION} - Database connected successfully to #{DB_URL.gsub(/:[^:@]+@/, ':***@')}"
rescue Sequel::DatabaseConnectionError => e
  LOGGER.error "Failed to connect to database: #{e.message}"
  raise
end

# Middleware
use Rack::Static, urls: { '/' => '/index.html' }, root: 'public', index: 'index.html'
use Rack::Static, urls: ['/images', '/robots.txt', '/favicon.ico'], root: 'public', index: 'index.html'

# Rate limiting
use Rack::Attack

# Use ActiveSupport::Cache::MemoryStore for rate limiting
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

# Throttle general requests by IP (100 requests per minute)
Rack::Attack.throttle('req/ip', limit: 100, period: 60) do |req|
  req.ip
end

# Throttle hit logging specifically (10 hits per minute)
Rack::Attack.throttle('hits/ip', limit: 10, period: 60) do |req|
  req.ip if req.path =~ %r{^/(y|youtube)$}
end

# Custom response for throttled requests
Rack::Attack.throttled_responder = lambda do |_env|
  [429, { 'content-type' => 'text/plain' }, ["Rate limit exceeded. Please try again later.\n"]]
end

unless DB.table_exists?(:hits)
  LOGGER.info "Creating hits table..."
  DB.create_table :hits do
    primary_key :id
    Inet :ip, null: false
    String :user_agent, null: false
    String :referer, null: false
    String :host, null: false
    Time :created_at, null: false

    index :ip
    index :created_at
    index :host
    index [:ip, :created_at]
  end
  LOGGER.info "Hits table created successfully"
else
  # Add missing indexes if table exists
  begin
    DB.add_index :hits, :ip unless DB.indexes(:hits).key?(:hits_ip_index)
    DB.add_index :hits, :created_at unless DB.indexes(:hits).key?(:hits_created_at_index)
    DB.add_index :hits, :host unless DB.indexes(:hits).key?(:hits_host_index)
  rescue Sequel::DatabaseError => e
    LOGGER.warn "Could not add indexes (may already exist): #{e.message}"
  end
end

# Main app
class HitLogApp
  def call(env)
    # Health check endpoint (before host validation)
    return health_check if env['PATH_INFO'] == '/health'

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
    # Check database connection
    begin
      DB.test_connection
      db_status = 'ok'
    rescue StandardError => e
      LOGGER.error "Health check failed - DB error: #{e.message}"
      db_status = 'error'
    end

    status = db_status == 'ok' ? 200 : 503
    body = {
      status: db_status == 'ok' ? 'healthy' : 'unhealthy',
      version: VERSION,
      database: db_status,
      timestamp: Time.now.iso8601
    }

    [status, { 'content-type' => 'application/json' }, [body.to_json]]
  end

  def hit!(env)
    ip = env['HTTP_X_REAL_IP'] || env['HTTP_X_FORWARDED_FOR']&.split(',')&.first&.strip || env['REMOTE_ADDR']
    user_agent = env['HTTP_USER_AGENT'] || 'Unknown'
    referer = env['HTTP_REFERER'] || ''
    host = env['HTTP_HOST']

    # Validate required fields
    if ip.nil? || ip.empty?
      LOGGER.warn "Hit rejected: missing IP address"
      return
    end

    # Sanitize inputs (basic validation)
    user_agent = user_agent[0...500] if user_agent.length > 500
    referer = referer[0...500] if referer.length > 500

    ::DB[:hits].insert(
      ip: ip,
      user_agent: user_agent,
      referer: referer,
      host: host,
      created_at: Time.now
    )

    LOGGER.info "Hit logged: IP=#{ip}, Host=#{host}, UA=#{user_agent[0...50]}"
  rescue Sequel::DatabaseError => e
    LOGGER.error "Database error while logging hit: #{e.message}"
    # Don't fail the request, just log the error
  rescue StandardError => e
    LOGGER.error "Unexpected error while logging hit: #{e.class} - #{e.message}"
  end
end

run HitLogApp.new
