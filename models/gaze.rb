class Gaze
  attr_accessor :x, :y, :pupil, :validity

  def initialize(x, y, pupil, validity)
    @x, @y, @pupil, @validity = x, y, pupil, validity
  end

  def to_json(*a)
    {
      x: @x,
      y: @y,
      pupil: @pupil,
      validity: @validity
    }.to_json(*a)
  end
end
