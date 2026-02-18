# frozen_string_literal: true

require 'rack'
require 'erb'
require_relative 'database'

# Admin panel module
module Admin
  module_function

  VIEWS_ROOT = File.expand_path('../views', __dir__)
  TEMPLATE_PATH = File.join(VIEWS_ROOT, 'admin', 'index.html.erb')
  TEMPLATE_ERB = ERB.new(File.read(TEMPLATE_PATH))
  HTML_ESCAPE = ERB::Util.method(:html_escape)
  URL_ENCODE = ERB::Util.method(:url_encode)

  def call(env)
    # HTTP Basic Auth
    auth = Rack::Auth::Basic::Request.new(env)
    unless auth.provided? && auth.basic? && auth.credentials == [ADMIN_USER, ADMIN_PASSWORD]
      return [401, { 'content-type' => 'text/plain', 'www-authenticate' => 'Basic realm="Admin Panel"' }, ["Unauthorized\n"]]
    end

    # Parse query params for pagination and filtering
    query = Rack::Utils.parse_query(env['QUERY_STRING'] || '')
    page = (query['page'] || 1).to_i
    page = 1 if page < 1
    per_page = 50

    # Filters
    ip_filter = query['ip']&.strip
    host_filter = query['host']&.strip

    # Get data
    result = Database.get_hits(page: page, per_page: per_page, ip_filter: ip_filter, host_filter: host_filter)
    hits = result[:hits]
    total_count = result[:total_count]
    total_pages = (total_count.to_f / per_page).ceil

    # Get hosts and stats
    hosts = Database.get_hosts
    stats = Database.get_stats

    # System info
    system_info = get_system_info

    # Render HTML
    html = render_html(hits, stats, system_info, page, total_pages, hosts, ip_filter, host_filter)

    [200, { 'content-type' => 'text/html; charset=utf-8' }, [html]]
  rescue StandardError => e
    LOGGER.error "Admin panel error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    [500, { 'content-type' => 'text/plain' }, ["Internal Server Error\n"]]
  end

  def get_system_info
    {
      version: VERSION,
      ruby_version: RUBY_VERSION,
      rack_version: Rack::VERSION,
      environment: ENV.fetch('RACK_ENV', 'development'),
      database_status: begin; DB.test_connection; 'connected'; rescue; 'error'; end,
      uptime: format_uptime(Time.now - APP_STARTED_AT),
      memory_usage: get_memory_usage,
      os_version: get_os_info,
      postgresql_version: Database.get_postgresql_version
    }
  end

  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.strip.to_i
  rescue StandardError
    'N/A'
  end

  def get_os_info
    `uname -srm`.strip
  rescue StandardError
    'N/A'
  end

  def format_uptime(seconds)
    return 'N/A' unless seconds.is_a?(Numeric)

    days = (seconds / 86400).to_i
    hours = ((seconds % 86400) / 3600).to_i
    minutes = ((seconds % 3600) / 60).to_i

    parts = []
    parts << "#{days} дн." if days > 0
    parts << "#{hours} ч." if hours > 0
    parts << "#{minutes} мин." if minutes > 0 || parts.empty?
    parts.join(' ')
  end

  def render_html(hits, stats, system_info, page, total_pages, hosts, ip_filter, host_filter)
    TEMPLATE_ERB.result_with_hash(
      hits: hits,
      stats: stats,
      system_info: system_info,
      page: page,
      total_pages: total_pages,
      hosts: hosts,
      ip_filter: ip_filter,
      host_filter: host_filter,
      version: VERSION,
      ruby_version: RUBY_VERSION,
      h: HTML_ESCAPE,
      u: URL_ENCODE
    )
  end
end
