class Gaze
  attr_accessor :x, :y, :pupil, :validity

  def initialize(x, y, pupil, validity)
    @x, @y, @pupil, @validity = x, y, pupil, validity
  end

  def to_hash(*a)
    {
      x: @x,
      y: @y,
      pupil: @pupil,
      validity: @validity
    }
  end
end
