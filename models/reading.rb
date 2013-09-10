require 'csv'

class Reading
  attr_accessor :flags, :samples

  VERSION = [0, 0, 0]

  def initialize(parser, filename)
    @samples = parser.parse(filename)
    @flags = parser.flags
  end

  def discard_invalid!()
    @samples = @samples.reject(&:invalid?)
  end

  def find_fixations!()
    fixation = @flags[:fixation]
    $stderr.puts @flags.inspect
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
    @row_bounds << [from, @samples.size] unless streak
  end

  def apply_smoothing!(window_size)
    window_half = window_size >> 1
    result = []

    window_left_x = []
    window_left_y = []
    window_left_pupil = []
    window_right_x = []
    window_right_y = []
    window_right_pupil = []

    @samples.each_with_index do |sample, index|
      # advance the windows
      window_left_x << (sample.left && sample.left.x)
      window_left_y << (sample.left && sample.left.y)
      window_left_pupil << (sample.left && sample.left.pupil)
      window_right_x << (sample.right && sample.right.x)
      window_right_y << (sample.right && sample.right.y)
      window_right_pupil << (sample.right && sample.right.pupil)

      if index >= window_size - 1
        mid_sample = @samples[index - window_size + window_half]

        if mid_sample.no_eyes?
          result << mid_sample
        else
          # calculate median sample
          left_x = median(window_left_x)
          left_y = median(window_left_y)
          left_pupil = median(window_left_pupil)
          right_x = median(window_right_x)
          right_y = median(window_right_y)
          right_pupil = median(window_right_pupil)

          left = Gaze.new(left_x, left_y, left_pupil, (left_x && left_y) ? 0 : 4)
          right = Gaze.new(right_x, right_y, right_pupil, (right_x && right_y) ? 0 : 4)
          result << Sample.new(mid_sample.time, left, right)
        end

        # shrink the windows
        window_left_x.shift
        window_left_y.shift
        window_left_pupil.shift
        window_right_x.shift
        window_right_y.shift
        window_right_pupil.shift
      end
    end

    @samples = result
  end

  def save_bin(file)
    payload = [VERSION, self]
    Zlib::GzipWriter.open(file) { |f| Marshal.dump(payload, f) }
    $stderr.puts "Saving to #{file}"
  end

  def self.load_bin(file)
    return nil unless File.exist?(file)
    version, reading = *Zlib::GzipReader.open(file) { |f| Marshal.load(f) }
    return nil if version != VERSION
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
