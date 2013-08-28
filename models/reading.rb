class Reading
  attr_accessor :flags

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

  X_THRESHOLD = 20
  def find_rows!
    last_sample = nil
    from = 0
    streak = false
    @row_bounds = []

    @samples.each_with_index do |sample, i|
      if last_sample &&
          ( # left
            !(
              last_sample.left &&
              last_sample.left.validity < 4 &&
              sample.left &&
              sample.left.validity < 4
            ) ||
            last_sample.left.x - X_THRESHOLD > sample.left.x &&
            last_sample.left.y < sample.left.y
          ) &&
          ( # right
            !(
              last_sample.right &&
              last_sample.right.validity < 4 &&
              sample.right &&
              sample.right.validity < 4
            ) ||
            last_sample.right.x - X_THRESHOLD > sample.right.x &&
            last_sample.right.y < sample.right.y
          )

        @row_bounds << [from, i] unless streak
        last_sample.rs = true
        streak = true
      elsif streak
        from = i if streak
        streak = false
      end
      last_sample = sample
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
