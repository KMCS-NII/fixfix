require 'sinatra/base'
require 'sinatra/url_for'
require 'json'
require 'zlib'
require 'time'


def ensure_sandboxed(file, dir)
  file = File.expand_path(file)
  dir = File.expand_path(dir)

  halt 403 unless file[0 .. dir.length - 1] == dir
end

module Routes
  def self.registered(app)
    # start page
    app.get "/?" do
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

            # for normal editing, just grab the latest version
            reading = Reading.load_bin(file + '.edit') if params[:cache]
            unless reading
              # for first display, try to load the original from cache,
              # and cache if we can't
              reading = Reading.load_bin(file + '.orig')
              unless reading
                reading = Reading.new(TobiiParser.new, file)
                reading.save_bin(file + '.orig')
              end

              # then find fixations if we needed them, and cache those
              # too as "edit version"
              if params[:dispersion]
                # fixation detection requested
                reading.flags[:fixation] = Hash[[:dispersion, :duration, :blink].map { |key|
                  [key, params[key].to_f]
                }]
                reading.find_fixations!
                reading.find_rows!
              end
              reading.save_bin(file + '.edit')
            end
            reading
          end

      content_type :json
      data.to_json
    end

    app.post '/change' do
      file = File.join('data', params[:file])
      ensure_sandboxed(file, 'data')
      reading = Reading.load_bin(file + '.edit')
      
      sample = reading.samples[params[:index].to_i]
      sample.left.x = params[:lx].to_f
      sample.left.y = params[:ly].to_f
      sample.right.x = params[:rx].to_f
      sample.right.y = params[:ry].to_f

      reading.flags[:dirty] = true
      reading.save_bin(file + '.edit')
    end

    app.get '/dl/*' do
      file = File.join('data', params[:splat])
      ensure_sandboxed(file, 'data')
      edit_file = file + '.edit'
      reading = Reading.load_bin(edit_file)

      last_modified File.mtime(edit_file).httpdate()

      headers = [
        "GazePointLeftX",
        "GazePointLeftY",
        "GazePointRightX",
        "GazePointRightX",
        "GazePointX",
        "GazePointX",
        "PupilLeft",
        "PupilRight",
        "RecordingTimestamp"
      ]

      content_type 'text/plain', :charset => 'utf-8'
      CSV.generate(
        col_sep: "\t",
        headers: headers,
        write_headers: true
      ) do |csv|
        reading.to_a.each do |sample_array|
          csv << sample_array
        end
      end
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
