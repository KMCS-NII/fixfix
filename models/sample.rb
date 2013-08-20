require 'json'

class Sample
  attr_accessor :break, :left, :right, :time, :blink

  VALIDITY_LIMIT = 4

  def initialize(time, left, right)
    @left = left
    @right = right
    @time = time
  end

  def invalid?
    (!@left.validity || @left.validity >= VALIDITY_LIMIT) &&
        (!@right.validity || @right.validity >= VALIDITY_LIMIT)
  end

  def to_json(*a)
    rep = {
      time: @time
    }
    rep[:left] = @left if @left
    rep[:right] = @right if @right
    rep[:blink] = @blink if @blink
    rep.to_json(*a)
  end
end
