class Reading
  attr_accessor :flags, :samples

  def initialize(parser, filename)
    @samples = parser.parse(filename)
    @flags = parser.flags
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

  def to_json(*a)
    {
      samples: @samples,
      flags: @flags,
      row_bounds: @row_bounds
    }.to_json(*a)
  end
end
