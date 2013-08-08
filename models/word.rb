require 'json'

class Word
  def initialize(*args)
    @word, @left, @top, @right, @bottom = *args
  end

  def self.from_tsv(line)
    word, coordinates = *(line.chomp.split("\t"))
    coordinates = coordinates.split(',').map(&:to_f)
    self.new(word, *coordinates)
  end

  def to_json(*opts)
    [@word, @left, @top, @right, @bottom].to_json
  end
end
