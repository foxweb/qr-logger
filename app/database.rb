# frozen_string_literal: true

require 'sequel'

# Database connection with error handling
begin
  DB = Sequel.connect(DB_URL)
  DB.extension :pg_inet
  LOGGER.info "QR Logger v#{VERSION} - Database connected successfully to #{DB_URL.gsub(/:[^:@]+@/, ':***@')}"
rescue Sequel::DatabaseConnectionError => e
  LOGGER.error "Failed to connect to database: #{e.message}"
  raise
end

# Create hits table if not exists
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

# Database operations module
module Database
  module_function

  def log_hit(ip:, user_agent:, referer:, host:)
    # Validate required fields
    if ip.nil? || ip.empty?
      LOGGER.warn "Hit rejected: missing IP address"
      return false
    end

    # Sanitize inputs (basic validation)
    user_agent = user_agent[0...500] if user_agent.length > 500
    referer = referer[0...500] if referer.length > 500

    DB[:hits].insert(
      ip: ip,
      user_agent: user_agent,
      referer: referer,
      host: host,
      created_at: Time.now
    )

    LOGGER.info "Hit logged: IP=#{ip}, Host=#{host}, UA=#{user_agent[0...50]}"
    true
  rescue Sequel::DatabaseError => e
    LOGGER.error "Database error while logging hit: #{e.message}"
    false
  rescue StandardError => e
    LOGGER.error "Unexpected error while logging hit: #{e.class} - #{e.message}"
    false
  end

  def get_hits(page: 1, per_page: 50, ip_filter: nil, host_filter: nil)
    offset = (page - 1) * per_page

    dataset = DB[:hits].order(Sequel.desc(:created_at))
    dataset = dataset.where(Sequel.expr { ip.cast(:text).ilike("%#{ip_filter}%") }) if ip_filter && !ip_filter.empty?
    dataset = dataset.where(host: host_filter) if host_filter && !host_filter.empty?

    {
      hits: dataset.limit(per_page, offset).all,
      total_count: dataset.count
    }
  end

  def get_hosts
    DB[:hits].distinct.select(:host).order(:host).map { |r| r[:host] }
  end

  def get_stats
    hosts = get_hosts
    {
      total_hits: DB[:hits].count,
      unique_ips: DB[:hits].distinct.select(:ip).count,
      today_hits: DB[:hits].where(created_at: Date.today..Date.today + 1).count,
      hosts_count: hosts.count
    }
  end

  def health_check
    begin
      DB.test_connection
      { status: 'ok', database: 'connected' }
    rescue StandardError => e
      LOGGER.error "Health check failed - DB error: #{e.message}"
      { status: 'error', database: 'disconnected' }
    end
  end

  def get_postgresql_version
    DB['SHOW server_version;'].first[:server_version]
  rescue StandardError
    'n/a'
  end
end
