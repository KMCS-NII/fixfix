require 'csv'

class FixFixParser
  def initialize(file)
    @file = file
  end

  def parse
    CSV.open(@file, "r", col_sep: "\t", headers: true) do |csv|
      csv.each.map { |row|
        # skip if row.header_row?
        numrow = row.map { |key, value| value_of(value) }
        Sample.from_a(*numrow)
      }
    end
  end

  def flags
    {
      center: true,
      lines: true,
      fixation: true,
    }
  end

  private
  def value_of(str)
    return nil unless str
    if str.include?('.')
      str.to_f
    else
      str.to_i
    end
  end
end
