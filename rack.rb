require 'rack'
require 'rack/server'
require 'sequel'

DB = Sequel.connect(adapter: 'postgres', database: 'analytics')

DB.create_table :hits do
  primary_key :id
  Inet :ip, null: false
  String :user_agent, null: false
  Time :created_at, null: false
end unless DB.table_exists?(:hits)

class HitLogApp
  def self.call(env)
    ::DB[:hits].insert(
      ip: env['REMOTE_ADDR'],
      user_agent: env['HTTP_USER_AGENT'],
      created_at: Time.now
    )
    [200, {'Content-Type' => 'text/plain'}, [env['HTTP_USER_AGENT']]]
    #[302, {'Location': 'https://www.youtube.com/channel/UCo4vIc1zKDHSioObftBYixg'}, []]
  end
end

