class Reading
  def initialize(parser, filename)
    @samples = parser.parse(filename)
    @flags = parser.flags
  end

  def find_fixations!(fixation_algorithm)
    @samples = fixation_algorithm.find_fixations(@samples)
    @flags[:lines] = true
    @flags[:center] = true
    self
  end

  X_THRESHOLD = 20
  def find_rows!
    last_sample = nil
    @samples.each do |sample|
      last_sample.rs = true if
          last_sample &&
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

      last_sample = sample
    end
  end

  def to_json(*a)
    {
      samples: @samples,
      flags: @flags
    }.to_json(*a)
  end
end
