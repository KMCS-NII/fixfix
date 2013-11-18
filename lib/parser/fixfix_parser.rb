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

  def self.generate(reading)
    headers = [
      "FixPointLeftX",
      "FixPointLeftY",
      "FixPointRightX",
      "FixPointRightX",
      "FixPointX",
      "FixPointX",
      "FixDuration",
      "MeanPupilLeft",
      "MeanPupilRight",
      "ReturnSweep",
      "BlinkTime",
      "MeanTimestamp",
      "StartTimestamp",
      "EndTimestamp",
    ]

    CSV.generate(
      col_sep: "\t",
      headers: headers,
      write_headers: true
    ) do |csv|
      reading.to_a.each do |sample_array|
        csv << sample_array
      end
    end
  end
end
