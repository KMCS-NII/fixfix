class Reading
  def initialize(parser, filename)
    @reading = parser.parse(filename)
  end

  def find_fixations!(fixation_algorithm)
    @reading = fixation_algorithm.find_fixations(@reading)
    self
  end

  def to_json(*a)
    @reading.to_json(*a)
  end
end
