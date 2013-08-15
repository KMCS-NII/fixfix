require 'json'

class Sample
  attr_accessor :break, :left, :right, :time, :blink

  def initialize(time, left, right)
    @left = left
    @right = right
    @time = time
  end

  def invalid?
    (!@left.validity || @left.validity == 4) &&
        (!@right.validity || @right.validity == 4)
  end

  def to_json(*a)
    {
      left: @left,
      right: @right,
      time: @time
    }.to_json(*a)
  end
end
