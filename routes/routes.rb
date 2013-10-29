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
    app.get '/load.json' do
      file = File.join('data', params[:load])
      ensure_sandboxed(file, 'data')

      payload = {}
      data = { payload: payload }

      extension = File.extname(file)[1 .. -1]
      case extension
      when 'bb'
        payload[:bb] = Word.load(file)
      when 'tsv'
        payload[:reading] = Reading.load(file, TobiiParser.new(file), params)
      when 'xml'
        xmlparser = XMLParser.new(file)
        payload[:reading] = Reading.load(file, xmlparser, params).find_rows!
        payload[:bb] = xmlparser.words
      when 'fixfix'
        payload[:reading] = Reading.load(file, FixFixParser.new(file), params, true).find_rows!
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
      file.chomp!(".fixfix")
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
        "ReturnSweep",
        "BlinkTime",
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
    app.post '/files' do
      dir = params[:dir]
      path = File.join('data', dir) 
      ensure_sandboxed(path, 'data')

      dirs = Dir[File.join(path, '*')].
          select { |item| File.directory?(item) }.
          map { |item| item[path.length .. -1] }.
          sort
      files = Dir[File.join(path, "*")].
          select { |item| %w(bb tsv fixfix xml).include?(File.extname(item)[1 .. -1]) }.
          map { |item| item[path.length .. -1] }.
          sort

      haml :file_tree, :locals => { dir: dir, dirs: dirs, files: files }
    end
  end
end
