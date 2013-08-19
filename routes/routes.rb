require 'sinatra/base'
require 'json'

def ensure_sandboxed(file, dir)
  file = File.expand_path(file)
  dir = File.expand_path(dir)

  halt 403 unless file[0 .. dir.length - 1] == dir
end

module Routes
  def self.registered(app)
    # start page
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
    app.get '/:type.json' do |type|
      file = File.join('data', params[:file])
      ensure_sandboxed(file, 'data')

      data = 
          case type
          when "bb"
            Word.load(file)
          when "gaze"
            Reading.new(TobiiParser.new, file)
          end

      content_type :json
      data.to_json
    end

    # file browser (by file extension)
    app.post '/files/:ext' do |ext|
      dir = params[:dir]
      path = File.join('data', dir) 
      ensure_sandboxed(path, 'data')

      dirs = Dir[File.join(path, '*')].
          select { |item| File.directory?(item) }.
          map { |item| item[path.length .. -1] }
      files = Dir[File.join(path, "*.#{ext}")].
          map { |item| item[path.length .. -1] }

      haml :file_tree, :locals => { dir: dir, dirs: dirs, files: files }
    end
  end
end
