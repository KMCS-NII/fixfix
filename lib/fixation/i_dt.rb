class I_DT
  # average blink is 100-400ms (Wikipedia)
  def initialize(dispersion, duration, blink=50)
    @dispersion = dispersion
    @duration = duration
    @blink = blink
  end

  def find_fixations(samples)
    fixations = []
    samples.reject! { |sample| !sample.time }

    until samples.empty?
      left_max_x = left_min_x = left_max_y = left_min_y = nil
      right_max_x = right_min_x = right_max_y = right_min_y = nil

      # skip over records that are invalid for both eyes
      blink = samples.take_while { |sample| sample.invalid? }
      unless blink.empty?
        samples.shift(blink.size)
        blink_time = blink.last.time - blink.first.time

        # is it a blink?
        if !fixations.empty? && blink_time > @blink
          fixations.last.blink = blink_time
        end
      end

      window = samples.take_while { |sample|
        # ...while the dispersion is small enough
        #
        # TODO: an idea: possibly admit samples where one eye
        # jumps out, as long as dispersion of the other eye is
        # under the threshold; in such a case, completely
        # ignore the jumping eye data

        unless invalid = sample.invalid?
          left_max_x = [sample.left.x, left_max_x].compact.max
          left_min_x = [sample.left.x, left_min_x].compact.min
          left_max_y = [sample.left.y, left_max_y].compact.max
          left_min_y = [sample.left.y, left_min_y].compact.min
          right_max_x = [sample.right.x, right_max_x].compact.max
          right_min_x = [sample.right.x, right_min_x].compact.min
          right_max_y = [sample.right.y, right_max_y].compact.max
          right_min_y = [sample.right.y, right_min_y].compact.min
        end

        !(invalid ||
            left_max_x && left_min_x && (left_max_x - left_min_x > @dispersion) ||
            left_max_y && left_min_y && (left_max_y - left_min_y > @dispersion) ||
            right_max_x && right_min_x && (right_max_x - right_min_x > @dispersion) ||
            right_max_y && right_min_y && (right_max_y - right_min_y > @dispersion))
      }
      
      if !window.empty? && window.last.time - window.first.time >= @duration
        # if the captured window is long enough, it's a fixation

        # calculate the centroid, apply weighting using validity
        total_left_weight = total_right_weight = 0
        c_left_x = c_left_y = c_left_pupil = c_left_validity = 0
        c_right_x = c_right_y = c_right_pupil = c_right_validity = 0
        c_time = 0

        window.each { |sample|
          left_weight = (4 - sample.left.validity) / 4.0
          total_left_weight += left_weight

          c_left_x += sample.left.x.to_f * left_weight
          c_left_y += sample.left.y.to_f * left_weight
          c_left_pupil += sample.left.pupil.to_f * left_weight
          c_left_validity += sample.left.validity * left_weight

          right_weight = (4 - sample.right.validity) / 4.0
          total_right_weight += right_weight

          c_right_x += sample.right.x.to_f * right_weight
          c_right_y += sample.right.y.to_f * right_weight
          c_right_pupil += sample.right.pupil.to_f * right_weight
          c_right_validity += sample.right.validity * right_weight

          c_time += sample.time
        }
        samples.shift(window.size)

        left =
            if total_left_weight != 0
              Gaze.new(
                c_left_x / total_left_weight,
                c_left_y / total_left_weight,
                c_left_pupil / total_left_weight,
                c_left_validity / total_left_weight)
            else
              Gaze.new(nil, nil, nil, 4)
            end
        right =
            if total_right_weight != 0
              Gaze.new(
                c_right_x / total_right_weight,
                c_right_y / total_right_weight,
                c_right_pupil / total_right_weight,
                c_right_validity / total_right_weight)
            else
              Gaze.new(nil, nil, nil, 4)
            end
        centroid = Sample.new(c_time / window.size, left, right)
        fixations << centroid
      else
        samples.shift
      end
    end

    fixations
  end
end
