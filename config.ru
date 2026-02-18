# frozen_string_literal: true

require_relative 'app/config'
require_relative 'app/database'
require_relative 'app/admin'
require_relative 'app/hit_log_app'
require 'rack'
require 'rack/attack'
require 'active_support'
require 'active_support/isolated_execution_state'
require 'active_support/cache'

# Middleware
use Rack::Static, urls: { '/' => '/index.html' }, root: 'public', index: 'index.html'
use Rack::Static, urls: ['/images', '/robots.txt', '/favicon.ico', '/admin.css'], root: 'public', index: 'index.html'

# Rate limiting
use Rack::Attack

# Use ActiveSupport::Cache::MemoryStore for rate limiting
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

# Throttle general requests by IP (100 requests per minute)
Rack::Attack.throttle('req/ip', limit: ENV.fetch('RATE_LIMIT_GENERAL', 100).to_i, period: 60) do |req|
  req.ip
end

# Throttle hit logging specifically (10 hits per minute)
Rack::Attack.throttle('hits/ip', limit: ENV.fetch('RATE_LIMIT_HITS', 10).to_i, period: 60) do |req|
  req.ip if req.path =~ %r{^/(y|youtube)$}
end

# Custom response for throttled requests
Rack::Attack.throttled_responder = lambda do |_env|
  [429, { 'content-type' => 'text/plain' }, ["Rate limit exceeded. Please try again later.\n"]]
end

run HitLogApp.new
