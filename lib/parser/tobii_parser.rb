class TobiiParser
  def parse(file)
    File.open(file, 'r:utf-8') do |f|
      # ignore the header
      f.gets

      # transform lines into Samples
      f.each_line.map { |line|
        parse_line(line)
      }
    end
  end

  def flags
    {
      center: true
    }
  end

  private
  def parse_line(line)
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
    gaze_point_left_x, gaze_point_left_y,
        gaze_point_right_x, gaze_point_right_y,
        _, _,
        pupil_left, pupil_right,
        validity_left, validity_right,
        time = *items
    left = Gaze.new(gaze_point_left_x, gaze_point_left_y, pupil_left, validity_left)
    right = Gaze.new(gaze_point_right_x, gaze_point_right_y, pupil_right, validity_right)
    Sample.new(time, left, right)
  end
end
