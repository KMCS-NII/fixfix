require 'json'

class Sample
  attr_accessor :left, :right, :time, :blink, :rs, :duration, :start_time, :end_time

  def initialize(time, left, right)
    @left = left
    @right = right
    @time = time
  end

  def no_eyes?
    @left.validity == 4
  end

  def valid?
    @time &&
        @left.validity && (@left.validity == 0 || @left.validity == 4) &&
        @right.validity && @right.validity == @left.validity
  end

  def to_a
    [
      left.x,
      left.y,
      right.x,
      right.y,
      if left.x && right.x then (left.x + right.x) / 2 else nil end,
      if left.y && right.y then (left.y + right.y) / 2 else nil end,
      duration,
      left.pupil,
      right.pupil,
      time,
      start_time,
      end_time,
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
    rep[:start_time] = @start_time if @start_time
    rep[:end_time] = @end_time if @end_time
    rep.to_json(*a)
  end
end
