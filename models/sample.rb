require 'json'

class Sample
  attr_accessor :first, :last

  def initialize(
      gaze_point_left_x, gaze_point_left_y,
      gaze_point_right_x, gaze_point_right_y,
      gaze_point_x, gaze_point_y,
      pupil_left, pupil_right,
      validity_left, validity_right,
      time
  )

    if validity_left.nil? || validity_right.nil? ||
        (validity = [validity_left + validity_right].max) > 0 ||
        time.nil?
      throw :invalid
    end

    pupil = if pupil_right && pupil_left
              (pupil_left + pupil_right) / 2
            else
              pupil_left || pupil_right
            end
    # (pupil size and validity are not pre-calculated,
    # as midpoint is)
    @left = Gaze.new(gaze_point_left_x, gaze_point_left_y, pupil_left, validity_left)
    @right = Gaze.new(gaze_point_right_x, gaze_point_right_y, pupil_right, validity_right)
    @avg = Gaze.new(gaze_point_x, gaze_point_y, pupil, validity)
    @time = time
  end

  def self.from_tsv_line(line)
    items = line.chomp.split("\t").
        map { |item|
          if item.strip.empty?
            nil
          elsif item.include?('.')
            item.to_f
          else
            item.to_i
          end
        }
    self.new(*items)
  end

  def self.from_tsv(file)
    File.open(file) do |f|
      f.each_line.
          # remove header
          reject { |line| line =~ /^\s*#/ }.
          # transform into Sample
          map { |line|
            catch(:invalid) { self.from_tsv_line(line) }
          }
          # remove consecutive nils
          # chunk { |sample| sample }.
          # map { |sample_group| sample_group.first }
    end
  end

  def to_json(*opts)
    (@left.to_a + @right.to_a + @avg.to_a + [@time]).
        to_json(*opts)
  end
end
