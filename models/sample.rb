require 'json'

class Sample
  attr_accessor :left, :right, :time, :blink, :rs, :duration

  VALIDITY_LIMIT = 0

  def initialize(time, left, right)
    @left = left
    @right = right
    @time = time
  end

  def invalid?
    (!@left.validity || @left.validity > VALIDITY_LIMIT) &&
        (!@right.validity || @right.validity > VALIDITY_LIMIT)
  end

  def to_a
    [
      left.x,
      left.y,
      right.x,
      right.y,
      (left.x + right.x) / 2,
      (left.y + right.y) / 2,
      left.pupil,
      right.pupil,
      time
    ]
  end

  def to_json(*a)
    rep = {
      time: @time
    }
    rep[:left] = @left if @left
    rep[:right] = @right if @right
    rep[:blink] = @blink if @blink
    rep[:rs] = @rs if @rs
    rep[:duration] = @duration if @duration
    rep.to_json(*a)
  end
end
