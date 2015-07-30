require 'json'

class Word
  def initialize(*args)
    @word, @left, @top, @right, @bottom = *args
  end

  def self.parse_line(line)
    word, coordinates = *(line.chomp.split("\t"))
    coordinates = coordinates.split(',').map(&:to_f)
    self.new(word, *coordinates)
  end

  def self.load(file)
    File.open(file, 'r:utf-8') do |f|
      f.each_line.
          reject { |line| line =~ /^\s*#/ }.
          map { |line| self.parse_line(line) }
    end
  end

  def to_hash
    {
      word: @word,
      left: @left,
      top: @top,
      right: @right,
      bottom: @bottom
    }
  end

  def to_json(*a)
    to_hash.to_json(*a)
  end
end
