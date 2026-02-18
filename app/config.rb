# frozen_string_literal: true

require 'dotenv'
Dotenv.load(File.expand_path('../../.env', __FILE__))
require 'logger'

# Version
VERSION = File.read(File.expand_path('../../VERSION', __FILE__)).strip.freeze

# App start time for uptime calculation
APP_STARTED_AT = Time.now.freeze

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

# Admin credentials
ADMIN_USER = ENV.fetch('ADMIN_USER', 'admin')
ADMIN_PASSWORD = ENV.fetch('ADMIN_PASSWORD', 'changeme')

LOGGER.info "QR Logger v#{VERSION} - Configuration loaded"
