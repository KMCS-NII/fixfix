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
      left.x.round,
      left.y.round,
      right.x.round,
      right.y.round,
      if left.x && right.x then ((left.x + right.x) / 2).round else nil end,
      if left.y && right.y then ((left.y + right.y) / 2).round else nil end,
      duration.round,
      left.pupil.round(2),
      right.pupil.round(2),
      blink,
      rs ? 1 : nil,
      time.round,
      start_time.round,
      end_time.round,
    ]
  end

  def self.from_a(lx, ly, rx, ry, cx, cy, duration, lp, rp, blink, rs, time, stime, etime)
    left = Gaze.new(lx, ly, lp, 0)
    right = Gaze.new(rx, ry, rp, 0)
    sample = Sample.new(time, left, right)
    sample.duration = duration
    sample.start_time = stime
    sample.end_time = etime
    sample.blink = blink
    sample.rs = rs == 1
    $stderr.puts sample.to_a.inspect
    sample
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
