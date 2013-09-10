require 'rbtree'

# This class implements fast rolling median
#
# Author::    Goran Topic
# Copyright:: Copyright (c) 2013 Goran Topic
# License::   MIT License
class MedianRoller
  attr_reader :result

  include Enumerable

  def initialize(window_size, data = nil, &value_proc)
    @cmp_proc = lambda { |a, b| value_proc[a] <=> value_proc[b] }
    reset
    @window_size = window_size
    @data = data
    @value_proc = (value_proc ||= lambda { |x| x })
    @medoid = false
  end

  def reset
    @median = nil
    @index = 0
    @result = []
    @window = []
    @s = MultiRBTree.new.readjust(@cmp_proc)
    @ge = MultiRBTree.new.readjust(@cmp_proc)
  end

  def medoid
    @medoid = true
    self
  end

  def add(element, &block)
    if @index >= @window_size
      old_element = @window.shift
      old_value = @value_proc[old_element]

      unless old_value.nil?
        if @median && old_value < @median
          @s.delete(old_element)
        else
          @ge.delete(old_element)
        end
      end
    end

    @index += 1
    @window << element
    value = @value_proc[element]

    unless value.nil?
      if @median && value < @median
        @s[element] = value
      else
        @ge[element] = value
      end
    end

    ge_size = @ge.size
    s_size = @s.size
    size_diff = ge_size - s_size
    actual_size = ge_size + s_size

    if size_diff > 1
      move_element, move_value = *@ge.shift
      @s[move_element] = move_value
    elsif size_diff < 0
      move_element, move_value = *@s.pop
      @ge[move_element] = move_value
    end

    if actual_size == 0
      @median = nil
    elsif @medoid || actual_size.odd?
      @median = @ge.first.last
    else
      @median = (@ge.first.last + @s.last.last) / 2.0
    end

    if @index >= @window_size
      if block_given?
        yield @median
      else
        @result << @median
      end
      @median
    end
  end

  def each(&block)
    reset
    enum = Enumerator.new do |yielder|
      @data.each do |element|
        add(element) { |median| yielder << median }
      end
    end
    enum.each(&block)
  end
end
