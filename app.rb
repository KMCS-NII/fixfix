# encoding: utf-8

dir = File.dirname(__FILE__)
%w(lib models routes).
  flat_map { |subdir| Dir["#{dir}/#{subdir}/**/*.rb"] }.
  each { |file| require file }

class FixFix < Sinatra::Application
  set :haml, format: :html5
  use Rack::Deflater

  # enable :sessions
  
  configure :production do
    set :haml, { ugly: true }
    set :clean_trace, true
  end

  # register the routes
  register Routes
end

