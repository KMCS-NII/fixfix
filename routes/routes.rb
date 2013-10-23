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
              # try the smoothing cache, if the smoothing level matches
              smoothing = params[:smoothing].to_i
              cache_smoothing = File.open(file + '.smlv') { |f| f.gets.to_i } rescue nil
              if cache_smoothing && cache_smoothing == smoothing
                reading = Reading.load_bin(file + '.smoo')
              end

              unless reading
                # try the original cache
                reading = Reading.load_bin(file + '.orig')

                unless reading
                  # load the original
                  reading = Reading.new(TobiiParser.new, file)
                  reading.save_bin(file + '.orig')
                end

                reading.discard_invalid!

                # median smoothing
                reading.apply_smoothing!(smoothing) unless smoothing <= 1
                reading.flags[:smoothing] = smoothing
                reading.save_bin(file + '.smoo')
                File.open(file + '.smlv', 'w') { |f| f.puts smoothing }
              end

              # then find fixations if we needed them, and cache those
              # too as "edit version"
              if params[:dispersion]
                # fixation detection
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
      
      JSON.parse(params[:changes]).each do |change|
        sample = reading.samples[change["index"]]
        sample.left.x = change["lx"]
        sample.left.y = change["ly"]
        sample.right.x = change["rx"]
        sample.right.y = change["ry"]
      end

      reading.flags[:dirty] = true
      reading.save_bin(file + '.edit')
    end

    app.get '/dl/*' do
      response.headers["Pragma"] = "no-cache"
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      response.headers["Expires"] = "0"

      file = File.join('data', params[:splat])
      ensure_sandboxed(file, 'data')
      edit_file = file + '.edit'
      reading = Reading.load_bin(edit_file)

      last_modified File.mtime(edit_file).httpdate()

      headers = [
        "FixPointLeftX",
        "FixPointLeftY",
        "FixPointRightX",
        "FixPointRightX",
        "FixPointX",
        "FixPointX",
        "FixDuration",
        "MeanPupilLeft",
        "MeanPupilRight",
        "MeanTimestamp",
        "StartTimestamp",
        "EndTimestamp",
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
