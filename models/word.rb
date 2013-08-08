require 'json'

class Word
  def initialize(*args)
    @word, @left, @top, @right, @bottom = *args
  end

  def self.from_tsv_line(line)
    word, coordinates = *(line.chomp.split("\t"))
    coordinates = coordinates.split(',').map(&:to_f)
    self.new(word, *coordinates)
  end

  def self.from_tsv(file)
    File.open(file) do |f|
      f.each_line.
          reject { |line| line =~ /^\s*#/ }.
          map { |line| self.from_tsv_line(line) }
    end
  end

  def to_json(*opts)
    [@word, @left, @top, @right, @bottom].to_json
  end
end
