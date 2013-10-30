class Reading
  attr_accessor :flags, :samples

  VERSION = [0, 0, 2]

  def initialize(parser, filename)
    @samples = parser.parse
    @flags = parser.flags
  end

  def discard_invalid!()
    # DEBUG    @samples = @samples.select(&:valid?)
    @samples = @samples.select { |sample|
      sample.valid?
    }
  end

  def find_fixations!()
    fixation = @flags[:fixation]
    fixation_algorithm = I_DT.new(fixation[:dispersion], fixation[:duration], fixation[:blink])
    @samples = fixation_algorithm.find_fixations(@samples)
    @flags[:lines] = true
    self
  end

  SACCADE_X_THRESHOLD = 20
  def return_sweep_part?(sample_gaze, last_sample_gaze)
    !(
      last_sample_gaze &&
      last_sample_gaze.validity < 4 &&
      sample_gaze &&
      sample_gaze.validity < 4
    ) ||
    last_sample_gaze.x - SACCADE_X_THRESHOLD > sample_gaze.x &&
    last_sample_gaze.y < sample_gaze.y
  end

  def find_rows!
    last_sample = nil
    last_index = 0
    from = 0
    streak = false
    @row_bounds = []

    @samples.each_with_index do |sample, i|
      if last_sample &&
          return_sweep_part?(sample.left, last_sample.left) &&
          return_sweep_part?(sample.right, last_sample.right)

        # return sweep part
        @row_bounds << [from, last_index] unless streak
        last_sample.rs = true
        streak = true
      elsif streak
        # normal saccade
        from = last_index if streak
        streak = false
      end
      last_sample = sample
      last_index = i
    end
    @row_bounds << [from, @samples.size - 1] unless streak
    self
  end

  def apply_smoothing!(window_size)
    left_x_medians = MedianRoller.new(window_size, @samples) { |sample| sample.left && sample.left.x }.each
    left_y_medians = MedianRoller.new(window_size, @samples) { |sample| sample.left && sample.left.y }.each
    left_pupil_medians = MedianRoller.new(window_size, @samples) { |sample| sample.left && sample.left.pupil }.each
    right_x_medians = MedianRoller.new(window_size, @samples) { |sample| sample.right && sample.right.x }.each
    right_y_medians = MedianRoller.new(window_size, @samples) { |sample| sample.right && sample.right.y }.each
    right_pupil_medians = MedianRoller.new(window_size, @samples) { |sample| sample.right && sample.right.pupil }.each

    result = []
    half_window = window_size / 2 - 1

    (window_size - half_window - 1 .. @samples.size - half_window - 1).each do |index|
      left_x = left_x_medians.next
      left_y = left_y_medians.next
      left_pupil = left_pupil_medians.next
      right_x = right_x_medians.next
      right_y = right_y_medians.next
      right_pupil = right_pupil_medians.next

      left = Gaze.new(left_x, left_y, left_pupil, left_x && left_y && left_pupil ? 0 : 4)
      right = Gaze.new(right_x, right_y, right_pupil, right_x && right_y && right_pupil ? 0 : 4)
      time = @samples[index].time

      result << Sample.new(time, left, right)
      index += 1
    end

    @samples = result
  end

  def save_bin(file)
    payload = [VERSION, self]
    Zlib::GzipWriter.open(file) { |f| Marshal.dump(payload, f) }
  end

  def self.load_bin(file)
    return nil unless File.exist?(file)
    version, reading = *Zlib::GzipReader.open(file) { |f| Marshal.load(f) }
    return nil if version != VERSION
    reading
  end

  def self.load(file, parser, params, processed=false)
    reading = nil

    # for normal editing, just grab the latest version
    reading = Reading.load_bin(file + '.edit') unless params[:nocache]

    unless reading
      unless processed
        # try the smoothing cache, if the smoothing level matches
        smoothing = params[:smoothing].to_i
        cache_smoothing = File.open(file + '.smlv') { |f| f.gets.to_i } rescue nil
        if cache_smoothing && cache_smoothing == smoothing
          reading = Reading.load_bin(file + '.smoo')
        end
      end

      unless reading
        # try the original cache
        reading = Reading.load_bin(file + '.orig')

        unless reading
          # load the original
          reading = Reading.new(parser, file)
          reading.save_bin(file + '.orig')
        end

        unless processed
          reading.discard_invalid!

          # median smoothing
          reading.apply_smoothing!(smoothing) unless smoothing <= 1
          reading.flags[:smoothing] = smoothing
          reading.save_bin(file + '.smoo')
          File.open(file + '.smlv', 'w') { |f| f.puts smoothing }
        end
      end

      unless processed
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
      end
      reading.save_bin(file + '.edit')
    end
    reading
  end

  def to_a
    @samples.map(&:to_a)
  end

  def to_json(*a)
    {
      samples: @samples,
      flags: @flags,
      row_bounds: @row_bounds
    }.to_json(*a)
  end

  private
  def median(array)
    array = array.compact.sort
    array[array.length >> 1]
  end
end
