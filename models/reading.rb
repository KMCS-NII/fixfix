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

  def to_json(*a)
    {
      samples: @samples,
      flags: @flags
    }.to_json(*a)
  end
end
