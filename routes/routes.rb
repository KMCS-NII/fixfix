require 'sinatra/base'
require 'json'

class ForbiddenException < Exception; end

def ensure_sandboxed(file, dir)
  file = File.expand_path(file)
  dir = File.expand_path(dir)

  raise ForbiddenException unless file[0 .. dir.length - 1] == dir
end

module Routes
  def self.registered(app)
    # NOTE remember that this works only when
    #     disable :show_exceptions
    # (which is enabled by default in `development` environment
    app.error ForbiddenException do
      status 403
    end

    app.get "/" do
      redirect request.url + '/' if request.path_info == ''
      haml :index
    end

    # Serve sources for source maps
    app.get %r((assets/.*)) do |path|
      ensure_sandboxed(path, 'assets')
      send_file path
    end

    # serve the data JSON
    app.get '/data.json' do
      bb_file, gaze_file = params.values_at(:bb, :gaze).map { |file| File.join('data', file) }
      ensure_sandboxed(bb_file, 'data')
      ensure_sandboxed(gaze_file, 'data')

      bb = File.open(bb_file) do |f|
        f.each_line.reject { |line|
          line =~ /^\s*#/
        }.map { |line|
          string, coordinates = *line.chomp.split("\t")
          coordinates = coordinates.split(',')
          Hash[%i(l t r b w).zip(coordinates << string)]
        }
      end


      content_type :json
      {
        bb: bb,
        gaze: {}
      }.to_json
    end

    app.post '/files/:ext' do |ext|
      dir = params[:dir]
      path = File.join('data', dir) 
      ensure_sandboxed(path, 'data')

      Dir.chdir(path) do
        dirs = Dir['*'].select { |item| File.directory?(item) }
        files = Dir["*.#{ext}"]

        haml :file_tree, :locals => { dir: dir, dirs: dirs, files: files }
      end
    end
  end
end
