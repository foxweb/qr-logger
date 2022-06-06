require './rack.rb'
Rack::Server.start(app: HitLogApp)

