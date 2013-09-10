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
    @window_size = window_size
    @index = 0
    @nils = 0
    @result = []
    @window = []
    @data = data
    @value_proc = (value_proc ||= lambda { |x| x })
    cmp_proc = lambda { |a, b| value_proc[a] <=> value_proc[b] }
    @s = RBTree.new.readjust(cmp_proc)
    @ge = RBTree.new.readjust(cmp_proc)
  end

  def add(element, &block)
    if @index >= @window_size
      old_element = @window.shift
      old_value = @value_proc[old_element]

      if old_value.nil?
        @nils -= 1
      elsif @median && old_value < @median
        @s.delete(old_element)
      else
        @ge.delete(old_element)
      end
    end

    @index += 1
    @window << element
    value = @value_proc[element]

    if value.nil?
      @nils += 1
    elsif @median && value < @median
      @s[element] = value
    else
      @ge[element] = value
    end

    size_diff = @ge.size - @s.size
    if size_diff > 1
      move_element, move_value = *@ge.shift
      @s[move_element] = move_value
    elsif size_diff < 0
      move_element, move_value = *@s.pop
      @ge[move_element] = move_value
    end

    @median = @ge.first.last
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
    enum = Enumerator.new do |yielder|
      @data.each do |element|
        add(element) { |median| yielder << median }
      end
    end
    enum.each(&block)
  end
end
