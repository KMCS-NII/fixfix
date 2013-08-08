class Gaze
  attr_reader :x, :y, :pupil, :validity

  def initialize(*args)
    @x, @y, @pupil, @validity = *args
  end

  def to_a(*opts)
    [ @x, @y, @pupil, @validity ]
  end
end
