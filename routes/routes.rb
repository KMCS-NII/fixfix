require 'sinatra/base'

module Routes
  def self.registered(app)
    app.get "/" do
      redirect request.url + '/' if request.path_info == ''
      haml :index
    end

    # Serve sources for source maps
    app.get %r((assets/.*)) do |path|
      path = File.expand_path(path)
      pwd = Dir.pwd

      if path[0 .. pwd.length - 1] == pwd
        send_file path
      else
        status 403
      end
    end
  end
end
