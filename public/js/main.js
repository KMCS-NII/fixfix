(function() {
  var Gaze, Reading, Sample, Word, ZOOM_SENSITIVITY, event_point, move_point, set_CTM, treedraw,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  ZOOM_SENSITIVITY = 0.2;

  event_point = function(svg, evt) {
    var p;
    p = svg.createSVGPoint();
    p.x = evt.clientX;
    p.y = evt.clientY;
    return p;
  };

  move_point = function(element, x_attr, y_attr, point) {
    if (element) {
      element.setAttribute(x_attr, point.x);
      return element.setAttribute(y_attr, point.y);
    }
  };

  set_CTM = function(element, matrix) {
    return element.transform.baseVal.initialize(element.ownerSVGElement.createSVGTransformFromMatrix(matrix));
  };

  treedraw = function(svg, parent, size, factor, callback) {
    var parents, recurse;
    if (!size) {
      return;
    }
    parents = [parent];
    recurse = function(parent, level) {
      var i, subparent, _i;
      if (level > 0) {
        level -= 1;
        for (i = _i = 1; 1 <= factor ? _i <= factor : _i >= factor; i = 1 <= factor ? ++_i : --_i) {
          subparent = level === 0 ? parent : svg.group(parent);
          recurse(subparent, level);
          if (!size) {
            return;
          }
        }
      } else {
        size -= 1;
        return callback(parent, size);
      }
    };
    return recurse(parent, Math.ceil(Math.log(size) / Math.log(factor)));
  };

  Word = (function() {
    function Word(word, left, top, right, bottom) {
      this.word = word;
      this.left = left;
      this.top = top;
      this.right = right;
      this.bottom = bottom;
    }

    Word.prototype.render_box = function(svg, parent) {
      return svg.rect(parent, this.left, this.top, this.right - this.left, this.bottom - this.top);
    };

    Word.prototype.render_word = function(svg, parent) {
      return svg.text(parent, (this.left + this.right) / 2, (this.top + this.bottom) / 2, this.word, {
        fontSize: this.bottom - this.top
      });
    };

    return Word;

  })();

  Gaze = (function() {
    function Gaze(x, y, pupil, validity) {
      this.x = x;
      this.y = y;
      this.pupil = pupil;
      this.validity = validity;
    }

    return Gaze;

  })();

  Sample = (function() {
    function Sample(time, rs, blink, left, right) {
      this.time = time;
      this.rs = rs;
      this.blink = blink;
      this.left = left;
      this.right = right;
    }

    Sample.prototype.build_center = function() {
      if ((this.left.x != null) && (this.left.y != null) && (this.right.x != null) && (this.right.y != null)) {
        return this.center = new Gaze((this.left.x + this.right.x) / 2, (this.left.y + this.right.y) / 2, (this.left.pupil + this.right.pupil) / 2, this.left.validity > this.right.validity ? this.left.validity : this.right.validity);
      }
    };

    Sample.prototype.render = function(svg, parent, eye) {
      var gaze;
      gaze = this[eye];
      if ((gaze != null) && (gaze.x != null) && (gaze.y != null) && (gaze.pupil != null)) {
        return this[eye].el = svg.circle(parent, gaze.x, gaze.y, gaze.pupil, {
          id: eye[0] + this.index,
          'data-index': this.index,
          'data-eye': eye,
          "class": 'drawn ' + eye
        });
      }
    };

    Sample.prototype.render_intereye = function(svg, parent) {
      if ((this.left.x != null) && (this.left.y != null) && (this.right.x != null) && (this.right.y != null)) {
        return this.iel = svg.line(parent, this.left.x, this.left.y, this.right.x, this.right.y, {
          id: 'i' + this.index,
          'data-index': this.index,
          "class": 'drawn inter'
        });
      }
    };

    Sample.prototype.render_saccade = function(svg, parent, eye, next) {
      var gaze1, gaze2, klass;
      gaze1 = this[eye];
      gaze2 = next[eye];
      if ((gaze1 != null) && (gaze2 != null) && (gaze1.x != null) && (gaze1.y != null) && (gaze2.x != null) && (gaze2.y != null)) {
        klass = 'drawn ' + eye;
        if (this.rs != null) {
          klass += ' rs';
        }
        if (this.blink != null) {
          klass += ' blink';
        }
        return this[eye].sel = svg.line(parent, gaze1.x, gaze1.y, gaze2.x, gaze2.y, {
          id: 's' + eye[0] + this.index,
          'data-index': this.index,
          "class": klass
        });
      }
    };

    return Sample;

  })();

  Reading = (function() {
    function Reading(samples, flags, row_bounds) {
      this.samples = samples;
      this.flags = flags;
      this.row_bounds = row_bounds;
    }

    Reading.prototype.find_row = function(index) {
      var from, to, _i, _len, _ref, _ref1;
      _ref = this.row_bounds;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        _ref1 = _ref[_i], from = _ref1[0], to = _ref1[1];
        if (index <= to) {
          if (index >= from) {
            return [from, to];
          }
          break;
        }
      }
      return [null, null];
    };

    Reading.prototype.toggle_class_on_range = function(from, to, klass, onoff) {
      var eye, ids, index, _i, _j, _k, _l, _len, _ref, _ref1;
      if (to == null) {
        return;
      }
      ids = [];
      _ref = ['l', 'c', 'r'];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        eye = _ref[_i];
        for (index = _j = from; from <= to ? _j <= to : _j >= to; index = from <= to ? ++_j : --_j) {
          ids.push('#' + eye + index);
        }
        for (index = _k = from, _ref1 = to - 1; from <= _ref1 ? _k <= _ref1 : _k >= _ref1; index = from <= _ref1 ? ++_k : --_k) {
          ids.push('#s' + eye + index);
        }
      }
      for (index = _l = from; from <= to ? _l <= to : _l >= to; index = from <= to ? ++_l : --_l) {
        ids.push('#i' + index);
      }
      return $(ids.join(', ')).toggleClass(klass, onoff);
    };

    Reading.prototype.toggle_class_on_row_of = function(index, klass, onoff) {
      var from, to, _ref;
      _ref = this.find_row(index), from = _ref[0], to = _ref[1];
      return this.toggle_class_on_range(from, to, klass, onoff);
    };

    Reading.prototype.highlight_row_of = function(index) {
      $('.drawn').addClass('faint');
      return this.toggle_class_on_row_of(index, 'faint', false);
    };

    Reading.prototype.unhighlight = function() {
      return $('.faint').removeClass('faint');
    };

    return Reading;

  })();

  window.FixFix = (function() {
    function FixFix(svg) {
      this.init = __bind(this.init, this);
      this.$svg = $(svg);
      this.data = {};
      $(this.$svg).svg({
        onLoad: this.init
      });
    }

    FixFix.prototype.init = function(svg) {
      var _this = this;
      this.svg = svg;
      this.root = this.svg.group();
      this.bb_group = this.svg.group(this.root, 'bb');
      this.gaze_group = this.svg.group(this.root, 'gaze');
      svg = this.svg._svg;
      $(svg).mousewheel(function(evt, delta, dx, dy) {
        var ctm, k, p, z;
        ctm = _this.root.getCTM();
        z = Math.pow(1 + ZOOM_SENSITIVITY, dy / 360);
        p = event_point(svg, evt).matrixTransform(ctm.inverse());
        k = svg.createSVGMatrix().translate(p.x, p.y).scale(z).translate(-p.x, -p.y);
        set_CTM(_this.root, ctm.multiply(k));
        return false;
      });
      $(svg).on('mousedown', function(evt) {
        var $target, index, node_name, unctm;
        node_name = evt.target.nodeName;
        unctm = _this.root.getCTM().inverse();
        if (node_name === 'circle') {
          $target = $(evt.target);
          index = $target.data('index');
          _this.data.gaze.highlight_row_of(index);
        } else if (node_name === 'svg') {

        } else {
          return;
        }
        _this.mousedown = {
          index: index,
          target: evt.target,
          eye: $target && $target.data('eye'),
          origin: event_point(svg, evt).matrixTransform(unctm),
          unctm: unctm
        };
        return _this.mousedrag = false;
      });
      $(svg).mousemove(function(evt) {
        var delta, eye, index, point, prev_sample, sample, unctm, _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7;
        if (_this.mousedown) {
          _this.mousedrag = true;
          _this.$svg.addClass('dragging');
        }
        if (_this.mousedrag) {
          unctm = _this.root.getCTM().inverse();
          point = event_point(svg, evt).matrixTransform(unctm);
          if (_this.mousedown.index != null) {
            index = _this.mousedown.index;
            eye = _this.mousedown.eye;
            sample = _this.data.gaze.samples[index];
            prev_sample = _this.data.gaze.samples[index - 1];
            delta = {
              x: point.x - sample[eye].x,
              y: point.y - sample[eye].y
            };
            sample[eye].x = point.x;
            sample[eye].y = point.y;
            if (eye === 'center') {
              sample.left.x += delta.x;
              sample.left.y += delta.y;
              sample.right.x += delta.x;
              sample.right.y += delta.y;
            } else {
              sample.center.x += delta.x / 2;
              sample.center.y += delta.y / 2;
            }
            if (sample.center) {
              move_point((_ref = sample.center) != null ? _ref.el : void 0, 'cx', 'cy', sample.center);
              move_point((_ref1 = sample.center) != null ? _ref1.sel : void 0, 'x1', 'y1', sample.center);
              move_point(prev_sample != null ? (_ref2 = prev_sample.center) != null ? _ref2.sel : void 0 : void 0, 'x2', 'y2', sample.center);
            }
            if (sample.left && eye !== 'right') {
              move_point((_ref3 = sample.left) != null ? _ref3.el : void 0, 'cx', 'cy', sample.left);
              move_point(sample != null ? sample.iel : void 0, 'x1', 'y1', sample.left);
              move_point((_ref4 = sample.left) != null ? _ref4.sel : void 0, 'x1', 'y1', sample.left);
              move_point(prev_sample != null ? prev_sample.left.sel : void 0, 'x2', 'y2', sample.left);
            }
            if (sample.right && eye !== 'left') {
              move_point((_ref5 = sample.right) != null ? _ref5.el : void 0, 'cx', 'cy', sample.right);
              move_point(sample != null ? sample.iel : void 0, 'x2', 'y2', sample.right);
              move_point((_ref6 = sample.right) != null ? _ref6.sel : void 0, 'x1', 'y1', sample.right);
              return move_point(prev_sample != null ? (_ref7 = prev_sample.right) != null ? _ref7.sel : void 0 : void 0, 'x2', 'y2', sample.right);
            }
          } else {
            return set_CTM(_this.root, unctm.inverse().translate(point.x - _this.mousedown.origin.x, point.y - _this.mousedown.origin.y));
          }
        }
      });
      return $(svg).mouseup(function(evt) {
        var payload, sample;
        if (_this.mousedrag) {
          _this.$svg.removeClass('dragging');
          if (_this.mousedown.index != null) {
            sample = _this.data.gaze.samples[_this.mousedown.index];
            _this.$svg.trigger('dirty');
            payload = {
              file: _this.data.gaze.opts.file,
              changes: JSON.stringify([
                {
                  index: _this.mousedown.index,
                  lx: sample.left.x,
                  ly: sample.left.y,
                  rx: sample.right.x,
                  ry: sample.right.y
                }
              ])
            };
            $.ajax({
              url: 'change',
              type: 'post',
              data: payload
            });
            _this.data.gaze.unhighlight();
          }
        }
        _this.mousedrag = false;
        return _this.mousedown = false;
      });
    };

    FixFix.prototype.load = function(file, type, opts) {
      var _this = this;
      opts = opts || {};
      opts.file = file;
      ($.ajax({
        url: "" + type + ".json",
        dataType: 'json',
        data: opts,
        revivers: function(k, v) {
          if ((v != null) && typeof v === 'object') {
            if ("word" in v) {
              return new Word(v.word, v.left, v.top, v.right, v.bottom);
            } else if ("validity" in v) {
              return new Gaze(v.x, v.y, v.pupil, v.validity);
            } else if ("time" in v) {
              return new Sample(v.time, v.rs, v.blink, v.left, v.right);
            } else if ("samples" in v) {
              return new Reading(v.samples, v.flags, v.row_bounds);
            }
          }
          return v;
        }
      })).then(function(data) {
        var index, sample, _i, _j, _len, _len1, _ref, _ref1;
        _this.data[type] = data;
        _this.data[type].opts = opts;
        switch (type) {
          case 'bb':
            return _this.render_bb();
          case 'gaze':
            if (_this.data.gaze.flags.center) {
              _ref = _this.data.gaze.samples;
              for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                sample = _ref[_i];
                sample.build_center();
              }
            }
            _ref1 = _this.data.gaze.samples;
            for (index = _j = 0, _len1 = _ref1.length; _j < _len1; index = ++_j) {
              sample = _ref1[index];
              sample.index = index;
            }
            _this.render_gaze();
            return _this.$svg.trigger('loaded');
        }
      });
      return delete opts.cache;
    };

    FixFix.prototype.render_bb = function() {
      var text_group, word, word_group, _i, _j, _len, _len1, _ref, _ref1, _results;
      $(this.bb_group).empty();
      word_group = this.svg.group(this.bb_group, 'text');
      _ref = this.data.bb;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        word = _ref[_i];
        word.render_box(this.svg, word_group);
      }
      text_group = this.svg.group(this.bb_group, 'text');
      _ref1 = this.data.bb;
      _results = [];
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        word = _ref1[_j];
        _results.push(word.render_word(this.svg, text_group));
      }
      return _results;
    };

    FixFix.prototype.render_gaze = function(opts) {
      var eye, samples, tree_factor, _results,
        _this = this;
      $(this.gaze_group).empty();
      tree_factor = 20;
      if (opts) {
        this.data.gaze.opts = opts;
      }
      samples = this.data.gaze.samples;
      if (this.data.gaze.flags.lines) {
        treedraw(this.svg, this.svg.group(this.gaze_group), samples.length, tree_factor, function(parent, index) {
          var sample;
          sample = samples[index];
          if (sample != null) {
            return sample.render_intereye(_this.svg, parent);
          }
        });
      }
      _results = [];
      for (eye in this.data.gaze.opts.eyes) {
        if (this.data.gaze.opts.eyes[eye]) {
          if (this.data.gaze.flags.lines) {
            treedraw(this.svg, this.svg.group(this.gaze_group), samples.length - 1, tree_factor, function(parent, index) {
              var sample1, sample2;
              sample1 = samples[index];
              sample2 = samples[index + 1];
              if ((sample1 != null) && (sample2 != null)) {
                return sample1.render_saccade(_this.svg, parent, eye, sample2);
              }
            });
          }
          _results.push(treedraw(this.svg, this.svg.group(this.gaze_group), samples.length, tree_factor, function(parent, index) {
            var sample;
            sample = samples[index];
            if (sample != null) {
              return sample.render(_this.svg, parent, eye);
            }
          }));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    return FixFix;

  })();

  window.FileBrowser = (function() {
    function FileBrowser(fixfix, bb_browser, gaze_browser) {
      var $bb_selected, $gaze_selected, fixations, load, load_timer, load_with_delay, opts, set_opts,
        _this = this;
      opts = {};
      fixations = null;
      $bb_selected = $();
      $gaze_selected = $();
      load_timer = null;
      set_opts = function() {
        var blink, dispersion, duration;
        fixations = $('#i-dt').is(':checked');
        if (fixations) {
          dispersion = parseInt($('#dispersion_n').val(), 10);
          duration = parseInt($('#duration_n').val(), 10);
          blink = parseInt($('#blink_n').val(), 10);
          opts = {
            dispersion: dispersion,
            duration: duration,
            blink: blink
          };
        } else {
          opts = {};
        }
        return opts.eyes = {
          left: $('#left-eye').is(':checked'),
          center: $('#center-eye').is(':checked'),
          right: $('#right-eye').is(':checked')
        };
      };
      $(bb_browser).fileTree({
        script: 'files/bb',
        multiFolder: false
      }, function(bb_file, $bb_newly_selected) {
        _this.bb_file = bb_file;
        $bb_selected.removeClass('selected');
        ($bb_selected = $bb_newly_selected).addClass('selected');
        return fixfix.load(bb_file, 'bb');
      });
      $(gaze_browser).fileTree({
        script: 'files/tsv',
        multiFolder: false
      }, function(gaze_file, $gaze_newly_selected) {
        _this.gaze_file = gaze_file;
        $gaze_selected.removeClass('selected');
        ($gaze_selected = $gaze_newly_selected).addClass('selected');
        opts.cache = true;
        return fixfix.load(_this.gaze_file, 'gaze', opts);
      });
      load = function() {
        if (_this.gaze_file) {
          set_opts();
          return fixfix.load(_this.gaze_file, 'gaze', opts);
        }
      };
      load_with_delay = function(evt) {
        clearTimeout(load_timer);
        return load_timer = setTimeout(load, 500);
      };
      $('#i-dt-options input[type="range"], #i-dt-options input[type="number"]').bind('input', function(evt) {
        if (fixations) {
          return load_with_delay();
        }
      });
      $('input[type="range"]').change(function(evt) {
        var $number, $target;
        $target = $(evt.target);
        $number = $target.next('input[type="number"]');
        if (($target != null) && $number.val() !== $target.val()) {
          return $number.val($target.val());
        }
      });
      $('input[type="number"]').change(function(evt) {
        var $number, $target;
        $target = $(evt.target);
        $number = $target.prev('input[type="range"]');
        if (($number != null) && $number.val() !== $target.val()) {
          return $number.val($target.val());
        }
      });
      $('#i-dt').click(load);
      $('#eye-options input').click(function(evt) {
        if (_this.gaze_file) {
          set_opts();
          return fixfix.render_gaze(opts);
        }
      });
      fixfix.$svg.on('loaded', function(evt) {
        var fixation_opts, key, value;
        fixation_opts = fixfix.data.gaze.flags.fixation;
        $('#i-dt').prop('checked', !!fixation_opts);
        if (fixation_opts) {
          for (key in fixation_opts) {
            value = fixation_opts[key];
            $("#" + key + ", #" + key + "-n").val(value);
          }
        }
        $('#fix-options').toggleClass('dirty', fixfix.data.gaze.flags.dirty);
        $('#tsv-link').attr('href', "dl" + _this.gaze_file);
        return $('#download').css('display', 'block');
      });
      fixfix.$svg.on('dirty', function(evt) {
        return $('#fix-options').addClass('dirty');
      });
      $('#scrap-changes-btn').click(function(evt) {
        load();
        return fixfix.$svg.trigger('clean');
      });
      set_opts();
    }

    return FileBrowser;

  })();

}).call(this);

/*
//@ sourceMappingURL=main.js.map
*/
