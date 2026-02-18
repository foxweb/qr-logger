# frozen_string_literal: true

require 'rack'
require_relative 'database'

# Admin panel module
module Admin
  module_function

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
    <<~HTML
      <!DOCTYPE html>
      <html lang="ru">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>QR Logger Admin</title>
        <style>
          * { box-sizing: border-box; }
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
          .container { max-width: 1400px; margin: 0 auto; }
          h1 { color: #333; margin-bottom: 20px; }
          h2 { color: #555; margin-top: 30px; border-bottom: 2px solid #ddd; padding-bottom: 10px; }

          /* Stats cards */
          .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
          .stat-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          .stat-card h3 { margin: 0 0 5px; color: #666; font-size: 14px; text-transform: uppercase; }
          .stat-card .value { font-size: 28px; font-weight: bold; color: #333; }

          /* System info */
          .system-info { background: #2d3748; color: #e2e8f0; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
          .system-info h2 { color: #fff; border-bottom-color: #4a5568; margin-top: 0; }
          .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; }
          .info-item { background: rgba(255,255,255,0.1); padding: 10px 15px; border-radius: 4px; }
          .info-item label { color: #a0aec0; font-size: 12px; text-transform: uppercase; }
          .info-item .value { color: #fff; font-weight: 500; margin-top: 3px; }
          .status-ok { color: #68d391 !important; }
          .status-error { color: #fc8181 !important; }

          /* Filters */
          .filters { background: white; padding: 15px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          .filters form { display: flex; gap: 15px; flex-wrap: wrap; align-items: flex-end; }
          .filter-group label { display: block; margin-bottom: 5px; font-size: 14px; color: #666; }
          .filter-group input, .filter-group select { padding: 8px 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; }
          .filter-group button { display: block; padding: 8px 20px; background: #4299e1; color: white; border: none; border-radius: 4px; cursor: pointer; }
          .filter-group button:hover { background: #3182ce; }
          .filter-group a { display: block; padding: 8px 20px; background: #e2e8f0; color: #4a5568; text-decoration: none; border-radius: 4px; }

          /* Table */
          .table-container { background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); overflow: hidden; }
          table { width: 100%; border-collapse: collapse; }
          th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #eee; }
          th { background: #f8f9fa; font-weight: 600; color: #555; position: sticky; top: 0; }
          tr:hover { background: #f8f9fa; }
          td { font-size: 14px; color: #333; }
          .ip-cell { font-family: monospace; }
          .time-cell { white-space: nowrap; color: #666; font-size: 13px; }
          .ua-cell { max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 12px; color: #666; }
          .host-badge { display: inline-block; padding: 2px 8px; background: #e2e8f0; border-radius: 4px; font-size: 12px; }
          .empty-state { text-align: center; padding: 40px; color: #999; }

          /* Pagination */
          .pagination { display: flex; justify-content: center; align-items: center; gap: 10px; padding: 20px; background: white; border-radius: 8px; margin-top: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          .pagination a, .pagination span { padding: 8px 12px; border: 1px solid #ddd; border-radius: 4px; text-decoration: none; color: #333; }
          .pagination a:hover { background: #f0f0f0; }
          .pagination .current { background: #4299e1; color: white; border-color: #4299e1; }
          .pagination .disabled { color: #ccc; cursor: not-allowed; }

          /* Footer */
          .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; margin-top: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>📊 QR Logger Admin</h1>

          <!-- Stats -->
          <div class="stats-grid">
            <div class="stat-card">
              <h3>Всего хитов</h3>
              <div class="value">#{stats[:total_hits]}</div>
            </div>
            <div class="stat-card">
              <h3>Уникальных IP</h3>
              <div class="value">#{stats[:unique_ips]}</div>
            </div>
            <div class="stat-card">
              <h3>Сегодня</h3>
              <div class="value">#{stats[:today_hits]}</div>
            </div>
            <div class="stat-card">
              <h3>Хостов</h3>
              <div class="value">#{stats[:hosts_count]}</div>
            </div>
          </div>

          <!-- System Info -->
          <div class="system-info">
            <h2>⚙️ Системная информация</h2>
            <div class="info-grid">
              <div class="info-item">
                <label>Версия приложения</label>
                <div class="value">v#{system_info[:version]}</div>
              </div>
              <div class="info-item">
                <label>Ruby</label>
                <div class="value">#{system_info[:ruby_version]}</div>
              </div>
              <div class="info-item">
                <label>Rack</label>
                <div class="value">#{system_info[:rack_version]}</div>
              </div>
              <div class="info-item">
                <label>Окружение</label>
                <div class="value">#{system_info[:environment]}</div>
              </div>
              <div class="info-item">
                <label>База данных</label>
                <div class="value #{system_info[:database_status] == 'connected' ? 'status-ok' : 'status-error'}">#{system_info[:database_status]}</div>
              </div>
              <div class="info-item">
                <label>Время работы</label>
                <div class="value">#{system_info[:uptime]}</div>
              </div>
              <div class="info-item">
                <label>Память (RSS)</label>
                <div class="value">#{system_info[:memory_usage].is_a?(Numeric) ? "#{(system_info[:memory_usage] / 1024.0).round(1)} MB" : system_info[:memory_usage]}</div>
              </div>
              <div class="info-item">
                <label>ОС</label>
                <div class="value">#{ERB::Util.html_escape(system_info[:os_version])}</div>
              </div>
              <div class="info-item">
                <label>PostgreSQL</label>
                <div class="value">#{ERB::Util.html_escape(system_info[:postgresql_version])}</div>
              </div>
            </div>
          </div>

          <!-- Filters -->
          <div class="filters">
            <form method="GET">
              <div class="filter-group">
                <label>IP адрес</label>
                <input type="text" name="ip" value="#{ERB::Util.html_escape(ip_filter)}" placeholder="Поиск по IP...">
              </div>
              <div class="filter-group">
                <label>Хост</label>
                <select name="host">
                  <option value="">Все хосты</option>
                  #{hosts.map { |h| "<option value=\"#{ERB::Util.html_escape(h)}\" #{h == host_filter ? 'selected' : ''}>#{ERB::Util.html_escape(h)}</option>" }.join("\n")}
                </select>
              </div>
              <div class="filter-group">
                <button type="submit">🔍 Фильтр</button>
              </div>
              <div class="filter-group">
                <a href="/admin">Сбросить</a>
              </div>
            </form>
          </div>

          <!-- Hits Table -->
          <div class="table-container">
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>IP адрес</th>
                  <th>Хост</th>
                  <th>User Agent</th>
                  <th>Referer</th>
                  <th>Время</th>
                </tr>
              </thead>
              <tbody>
                #{if hits.empty?
                  '<tr><td colspan="6" class="empty-state">Нет данных для отображения</td></tr>'
                else
                  hits.map do |hit|
                    "<tr>
                      <td>#{hit[:id]}</td>
                      <td class=\"ip-cell\">#{ERB::Util.html_escape(hit[:ip])}</td>
                      <td><span class=\"host-badge\">#{ERB::Util.html_escape(hit[:host])}</span></td>
                      <td class=\"ua-cell\" title=\"#{ERB::Util.html_escape(hit[:user_agent])}\">#{ERB::Util.html_escape(hit[:user_agent])}</td>
                      <td class=\"ua-cell\">#{hit[:referer].to_s.empty? ? '' : ERB::Util.html_escape(hit[:referer])}</td>
                      <td class=\"time-cell\">#{hit[:created_at].strftime('%d.%m.%Y %H:%M:%S')}</td>
                    </tr>"
                  end.join("\n")
                end}
              </tbody>
            </table>
          </div>

          <!-- Pagination -->
          #{if total_pages > 1
            prev_link = page > 1 ? "<a href=\"?page=#{page - 1}#{ip_filter ? "&ip=#{ERB::Util.url_encode(ip_filter)}" : ''}#{host_filter ? "&host=#{ERB::Util.url_encode(host_filter)}" : ''}\">← Назад</a>" : '<span class="disabled">← Назад</span>'
            next_link = page < total_pages ? "<a href=\"?page=#{page + 1}#{ip_filter ? "&ip=#{ERB::Util.url_encode(ip_filter)}" : ''}#{host_filter ? "&host=#{ERB::Util.url_encode(host_filter)}" : ''}\">Далее →</a>" : '<span class="disabled">Далее →</span>'

            pages_html = (1..total_pages).map do |p|
              if p == page
                "<span class=\"current\">#{p}</span>"
              elsif (p - page).abs <= 3
                "<a href=\"?page=#{p}#{ip_filter ? "&ip=#{ERB::Util.url_encode(ip_filter)}" : ''}#{host_filter ? "&host=#{ERB::Util.url_encode(host_filter)}" : ''}\">#{p}</a>"
              end
            end.compact.join("\n")

            "<div class=\"pagination\">#{prev_link} #{pages_html} #{next_link}</div>"
          else
            ''
          end}

          <div class="footer">
            QR Logger v#{VERSION} • Powered by Ruby #{RUBY_VERSION}
          </div>
        </div>
      </body>
      </html>
    HTML
  end
end