# frozen_string_literal: true

require 'rack'
require 'sequel'

use Rack::Static, urls: { '/' => 'index.html' }, root: 'public'

HOSTNAMES = ['kurepin.com', 'k5r.ru'].freeze
REDIRECT_TO = 'https://k5r.ru/'
DB = Sequel.connect('postgres://qrlogger:qrlogger@db/analytics')

unless DB.table_exists?(:hits)
  DB.create_table :hits do
    primary_key :id
    Inet :ip, null: false
    String :user_agent, null: false
    String :referer, null: false
    String :host, null: false
    Time :created_at, null: false
  end
end

# Main app
class HitLogApp
  def call(env)
    return [444, {}, []] unless HOSTNAMES.include?(env['HTTP_HOST'])

    case [env['REQUEST_METHOD'], env['PATH_INFO']]
    when ['GET', '/y']
      hit!(env)
    when ['GET', '/test']
      return [200, {}, [env['HTTP_USER_AGENT'], "\n", env['REMOTE_ADDR']]]
    end
    [302, { 'location' => REDIRECT_TO }, []]
  end

  private

  def hit!(env)
    ::DB[:hits].insert(
      ip: env['HTTP_X_REAL_IP'] || env['REMOTE_ADDR'],
      user_agent: env['HTTP_USER_AGENT'],
      referer: env['HTTP_REFERER'] || '',
      host: env['HTTP_HOST'],
      created_at: Time.now
    )
  end
end

run HitLogApp.new
