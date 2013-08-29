require 'sinatra/base'
require 'json'
require 'zlib'

VERSION = [0, 0, 0]

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
            reading = nil

            if params[:cache] && File.exist?(file + '.edit')
              # for normal editing, just grab the latest version
              version, reading = *Zlib::GzipReader.open(file + '.edit') { |f| Marshal.load(f) }
              reading = nil if version != VERSION
            end
            unless reading
              # for first display, try to load the original from cache,
              # and cache if we can't
              if File.exist?(file + '.orig')
                version, reading = *Zlib::GzipReader.open(file + '.orig') { |f| Marshal.load(f) }
                reading = nil if version != VERSION
              end
              unless reading
                reading = Reading.new(TobiiParser.new, file)
                payload = [VERSION, reading]
                Zlib::GzipWriter.open(file + '.orig') { |f| Marshal.dump(payload, f) }
              end

              # then find fixations if we needed them, and cache those
              # too as "edit version"
              if params[:dispersion]
                # fixation detection requested
                reading.flags[:fixation] = Hash[%i(dispersion duration blink).map { |key|
                  [key, params[key].to_f]
                }]
                reading.find_fixations!
                reading.find_rows!
              end
              payload = [VERSION, reading]
              Zlib::GzipWriter.open(file + '.edit') { |f| Marshal.dump(payload, f) }
            end
            reading
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
          map { |item| item[path.length .. -1] }.
          sort
      files = Dir[File.join(path, "*.#{ext}")].
          map { |item| item[path.length .. -1] }.
          sort

      haml :file_tree, :locals => { dir: dir, dirs: dirs, files: files }
    end
  end
end
