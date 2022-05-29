require 'rack/app'
require 'sequel'

DB = Sequel.connect(adapter: 'postgres', database: 'analytics')

class App < Rack::App
  desc 'healthcheck endpoint'
  get '/' do
    'OK'
  end

  get '/youtube' do
    ::DB[:hits].insert(
      ip: request.env['REMOTE_ADDR'],
      user_agent: request.env['HTTP_USER_AGENT'],
      created_at: Time.now
    )
    # redirect_to 'https://www.youtube.com/channel/UCo4vIc1zKDHSioObftBYixg'
  end
end

