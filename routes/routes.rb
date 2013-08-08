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
    app.get '/data.json' do
      bb_file, gaze_file = params.
          values_at(:bb, :gaze).
          map { |file| File.join('data', file) }
      ensure_sandboxed(bb_file, 'data')
      ensure_sandboxed(gaze_file, 'data')

      content_type :json
      {
        bb: Word.from_tsv(bb_file),
        gaze: Sample.from_tsv(gaze_file),
      }.to_json
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
