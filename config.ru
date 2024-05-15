# frozen_string_literal: true

require 'rack'
require 'rack/server'
require 'sequel'

DB = Sequel.connect('postgres://qrlogger:qrlogger@db/analytics')

unless DB.table_exists?(:hits)
  DB.create_table :hits do
    primary_key :id
    Inet :ip, null: false
    String :user_agent, null: false
    String :referer, null: false
    Time :created_at, null: false
  end
end

class HitLogApp
  def self.call(env)
    ::DB[:hits].insert(
      ip: env['HTTP_X_REAL_IP'] || env['REMOTE_ADDR'],
      user_agent: env['HTTP_USER_AGENT'],
      referer: env['HTTP_REFERER'],
      created_at: Time.now
    )
    # for testing
    # [200, {'Content-Type' => 'text/plain'}, [env['HTTP_USER_AGENT']]]
    [302, { 'Location' => 'https://www.youtube.com/@foxwwweb/videos' }, []]
  end
end

Rack::Server.start(app: HitLogApp)
