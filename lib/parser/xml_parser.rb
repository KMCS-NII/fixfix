require 'nokogiri'

class XMLParser
  def initialize(file)
    @file = file
  end

  def doc_and_words
    @doc = File.open(@file) { |f| Nokogiri::XML(f.read) }
    @words = @doc.css('FinalTextChar > CharPos').map { |char|
      x = char[:X].to_i
      y = char[:Y].to_i
      w = char[:Width].to_i
      h = char[:Height].to_i
      Word.new(char[:Value], x, y, x + w, y + h)
    }
  end

  def parse
    doc_and_words

    # @doc.css('Events > Fix[Dur]').map { |element|
    #   # x = element[:X].to_i
    #   # y = element[:Y].to_i
    #   xl = element[:Xl].to_i
    #   yl = element[:Yl].to_i
    #   xr = element[:Xr].to_i
    #   yr = element[:Yr].to_i
    #   time = element[:Time].to_i
    #   left = Gaze.new(xl, yl, nil, 0)
    #   right = Gaze.new(xr, yr, nil, 0)
    #   Sample.new(time, left, right)
    # }
    @doc.css('Events > Eye').map { |element|
      # x = element[:X].to_i
      # y = element[:Y].to_i
      xl = element[:Xl].to_i
      yl = element[:Yl].to_i
      pl = element[:pl].to_f
      xr = element[:Xr].to_i
      yr = element[:Yr].to_i
      pr = element[:pr].to_f
      vl = pl == -1 ? 4 : 0
      vr = pr == -1 ? 4 : 0
      time = element[:Time].to_i
      left = Gaze.new(xl, yl, pl, vl)
      right = Gaze.new(xr, yr, pr, vr)
      Sample.new(time, left, right)
    }
  end

  def flags
    {
      center: true
    }
  end

  def words
    doc_and_words unless @words
    @words
  end
end
