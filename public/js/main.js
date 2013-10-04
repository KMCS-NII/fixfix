(function() {
  var Gaze, Reading, Sample, UndoStack, UndoState, Word, ZOOM_SENSITIVITY, event_point, move_point, set_CTM, treedraw,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  ZOOM_SENSITIVITY = 0.2;

  $.contextMenu.shadow = false;

  $.contextMenu.theme = navigator.platform.match(/Mac/) ? "osx" : navigator.platform.match(/Linux/) ? "human" : navigator.platform.match(/Win/) ? "vista" : "default";

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
      var frozen, gaze;
      gaze = this[eye];
      frozen = this.frozen ? ' frozen' : '';
      if ((gaze != null) && (gaze.x != null) && (gaze.y != null) && (gaze.pupil != null)) {
        return this[eye].el = svg.circle(parent, gaze.x, gaze.y, 3, {
          id: eye[0] + this.index,
          'data-index': this.index,
          'data-eye': eye,
          "class": 'drawn ' + eye + frozen
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
        klass = 'saccade drawn ' + eye;
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

    Sample.prototype.fix = function(value) {
      var circles, _ref, _ref1, _ref2;
      if (value == null) {
        value = true;
      }
      this.frozen = value;
      circles = $([(_ref = this.left) != null ? _ref.el : void 0, (_ref1 = this.center) != null ? _ref1.el : void 0, (_ref2 = this.right) != null ? _ref2.el : void 0]);
      return circles.toggleClass('frozen', value);
    };

    return Sample;

  })();

  Reading = (function() {
    function Reading(samples, flags, row_bounds) {
      var from, to, _i, _len, _ref, _ref1;
      this.samples = samples;
      this.flags = flags;
      this.row_bounds = row_bounds;
      _ref = this.row_bounds;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        _ref1 = _ref[_i], from = _ref1[0], to = _ref1[1];
        this.samples[from].frozen = true;
        this.samples[to].frozen = true;
      }
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
      var elements, eye, index, sample, sample_eye, _i, _j, _k, _len, _len1, _ref, _ref1;
      if (to == null) {
        return;
      }
      elements = [];
      if ((sample = this.samples[from - 1])) {
        _ref = ['left', 'center', 'right'];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          eye = _ref[_i];
          if ((sample_eye = sample[eye])) {
            elements.push(sample.sel);
          }
        }
      }
      for (index = _j = from; from <= to ? _j <= to : _j >= to; index = from <= to ? ++_j : --_j) {
        sample = this.samples[index];
        elements.push(sample.iel);
        _ref1 = ['left', 'center', 'right'];
        for (_k = 0, _len1 = _ref1.length; _k < _len1; _k++) {
          eye = _ref1[_k];
          if ((sample_eye = sample[eye])) {
            elements.push(sample_eye.el);
            elements.push(sample_eye.sel);
          }
        }
      }
      return $(elements).toggleClass(klass, onoff);
    };

    Reading.prototype.toggle_class_on_row_of = function(index, klass, onoff) {
      var from, to, _ref;
      _ref = this.find_row(index), from = _ref[0], to = _ref[1];
      return this.toggle_class_on_range(from, to, klass, onoff);
    };

    Reading.prototype.highlight_row_of = function(index) {
      $('#gaze').addClass('faint');
      return this.toggle_class_on_row_of(index, 'highlight', true);
    };

    Reading.prototype.highlight_range = function(from, to) {
      $('#gaze').addClass('faint');
      return this.toggle_class_on_range(from, to, 'highlight', true);
    };

    Reading.prototype.unhighlight = function() {
      $('#gaze').removeClass('faint');
      return $('.highlight').removeClass('highlight');
    };

    Reading.prototype.save = function(from, to) {
      var changes, index, payload, sample, _i;
      changes = [];
      for (index = _i = from; from <= to ? _i <= to : _i >= to; index = from <= to ? ++_i : --_i) {
        sample = this.samples[index];
        changes.push({
          index: index,
          lx: sample.left.x,
          ly: sample.left.y,
          rx: sample.right.x,
          ry: sample.right.y
        });
      }
      payload = {
        file: this.opts.file,
        changes: JSON.stringify(changes)
      };
      return $.ajax({
        url: 'change',
        type: 'post',
        data: payload
      });
    };

    return Reading;

  })();

  UndoState = (function() {
    function UndoState(data, from, to) {
      var index, sample, _i, _ref, _ref1;
      this.data = data;
      this.from = from;
      this.to = to;
      this.records = [];
      for (index = _i = _ref = this.from, _ref1 = this.to; _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; index = _ref <= _ref1 ? ++_i : --_i) {
        sample = this.data.gaze.samples[index];
        this.records.push([sample.left.x, sample.left.y, sample.center.x, sample.center.y, sample.right.x, sample.right.y]);
      }
    }

    UndoState.prototype.restore = function() {
      var eye, index, last_sample, sample, _i, _j, _len, _ref, _ref1, _ref2, _ref3, _ref4, _ref5;
      for (index = _i = _ref = this.from, _ref1 = this.to; _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; index = _ref <= _ref1 ? ++_i : --_i) {
        sample = this.data.gaze.samples[index];
        _ref2 = this.records.pop(), sample.left.x = _ref2[0], sample.left.y = _ref2[1], sample.center.x = _ref2[2], sample.center.y = _ref2[3], sample.right.x = _ref2[4], sample.right.y = _ref2[5];
        last_sample = this.data.gaze.samples[index - 1];
        _ref3 = ['left', 'center', 'right'];
        for (_j = 0, _len = _ref3.length; _j < _len; _j++) {
          eye = _ref3[_j];
          if ((_ref4 = sample[eye]) != null ? _ref4.el : void 0) {
            sample[eye].el.setAttribute('cx', sample[eye].x);
            sample[eye].el.setAttribute('cy', sample[eye].y);
          }
          if (sample[eye].sel) {
            sample[eye].sel.setAttribute('x1', sample[eye].x);
            sample[eye].sel.setAttribute('y1', sample[eye].y);
          }
          if (last_sample && ((_ref5 = last_sample[eye]) != null ? _ref5.sel : void 0)) {
            last_sample[eye].sel.setAttribute('x2', sample[eye].x);
            last_sample[eye].sel.setAttribute('y2', sample[eye].y);
          }
        }
        if (sample.iel) {
          sample.iel.setAttribute('x1', sample.left.x);
          sample.iel.setAttribute('y1', sample.left.y);
          sample.iel.setAttribute('x2', sample.right.x);
          sample.iel.setAttribute('y2', sample.right.y);
        }
      }
      return [this.from, this.to];
    };

    return UndoState;

  })();

  UndoStack = (function() {
    function UndoStack(data) {
      this.data = data;
      this.stack = [];
    }

    UndoStack.prototype.push = function(from, to) {
      return this.stack.push(new UndoState(this.data, from, to));
    };

    UndoStack.prototype.pop = function() {
      return this.stack.pop().restore();
    };

    UndoStack.prototype.empty = function() {
      return !this.stack.length;
    };

    return UndoStack;

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
      var arrow, mh, mw, stopDrag,
        _this = this;
      this.svg = svg;
      this.root = this.svg.group();
      this.defs = this.svg.defs();
      mh = mw = 5;
      arrow = this.svg.marker(this.defs, 'arrow', mw, mh / 2, mw, mh, 'auto', {
        markerUnits: 'userSpaceOnUse',
        color: 'black'
      });
      this.svg.polyline(arrow, [[0, 0], [[mw, mh / 2], [0, mh], [mw / 12, mh / 2]]]);
      this.svg.style(this.defs, "#gaze line.drawn.saccade.highlight { marker-end: url(#arrow) }");
      this.bb_group = this.svg.group(this.root, 'bb');
      this.gaze_group = this.svg.group(this.root, 'gaze');
      this.single_mode = false;
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
        var $target, from, index, node_name, row_from, row_to, to, unctm, _i, _j, _ref, _ref1;
        node_name = evt.target.nodeName;
        unctm = _this.root.getCTM().inverse();
        switch (evt.button) {
          case 1:
            if (node_name === 'circle') {
              $target = $(evt.target);
              index = $target.data('index');
              _this.data.gaze.highlight_row_of(index);
              if (_this.single_mode) {
                from = to = index;
              } else {
                _ref1 = (_ref = _this.data.gaze.find_row(index), row_from = _ref[0], row_to = _ref[1], _ref), from = _ref1[0], to = _ref1[1];
                for (from = _i = index; index <= row_from ? _i <= row_from : _i >= row_from; from = index <= row_from ? ++_i : --_i) {
                  if (from === row_from || (from !== index && _this.data.gaze.samples[from].frozen)) {
                    break;
                  }
                }
                for (to = _j = index; index <= row_to ? _j <= row_to : _j >= row_to; to = index <= row_to ? ++_j : --_j) {
                  if (to === row_to || (to !== index && _this.data.gaze.samples[to].frozen)) {
                    break;
                  }
                }
              }
              _this.undo.push(from, to);
            } else if (node_name === 'svg') {

            } else {
              return;
            }
            _this.mousedown = {
              unctm: unctm,
              origin: event_point(svg, evt).matrixTransform(unctm),
              index: index,
              target: index && evt.target,
              eye: (index != null) && $target.data('eye'),
              row: [from, to]
            };
            return _this.mousedrag = false;
        }
      });
      $(svg).mousemove(function(evt) {
        var a_x, a_y, delta, extent, eye, from, index, index_diff, point, point_delta, prev_sample, sample, to, unctm, _i, _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _results;
        if (_this.mousedown) {
          _this.mousedrag = true;
          _this.$svg.addClass('dragging');
        }
        if (_this.mousedrag) {
          unctm = _this.root.getCTM().inverse();
          point = event_point(svg, evt).matrixTransform(unctm);
          if (_this.mousedown.index != null) {
            eye = _this.mousedown.eye;
            _ref = _this.mousedown.row, from = _ref[0], to = _ref[1];
            sample = _this.data.gaze.samples[_this.mousedown.index];
            point_delta = {
              x: point.x - sample[eye].x,
              y: point.y - sample[eye].y
            };
            extent = from - _this.mousedown.index;
            a_x = -point_delta.x / (extent * extent);
            a_y = -point_delta.y / (extent * extent);
            prev_sample = _this.data.gaze.samples[from - 1];
            _results = [];
            for (index = _i = from; from <= to ? _i <= to : _i >= to; index = from <= to ? ++_i : --_i) {
              sample = _this.data.gaze.samples[index];
              index_diff = index - _this.mousedown.index;
              if (index_diff === 0) {
                extent = to - _this.mousedown.index;
                a_x = -point_delta.x / (extent * extent);
                a_y = -point_delta.y / (extent * extent);
                delta = point_delta;
              } else {
                delta = {
                  x: a_x * index_diff * index_diff + point_delta.x,
                  y: a_y * index_diff * index_diff + point_delta.y
                };
              }
              sample[eye].x += delta.x;
              sample[eye].y += delta.y;
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
                move_point((_ref1 = sample.center) != null ? _ref1.el : void 0, 'cx', 'cy', sample.center);
                move_point((_ref2 = sample.center) != null ? _ref2.sel : void 0, 'x1', 'y1', sample.center);
                move_point(prev_sample != null ? (_ref3 = prev_sample.center) != null ? _ref3.sel : void 0 : void 0, 'x2', 'y2', sample.center);
              }
              if (sample.left && eye !== 'right') {
                move_point((_ref4 = sample.left) != null ? _ref4.el : void 0, 'cx', 'cy', sample.left);
                move_point(sample != null ? sample.iel : void 0, 'x1', 'y1', sample.left);
                move_point((_ref5 = sample.left) != null ? _ref5.sel : void 0, 'x1', 'y1', sample.left);
                move_point(prev_sample != null ? prev_sample.left.sel : void 0, 'x2', 'y2', sample.left);
              }
              if (sample.right && eye !== 'left') {
                move_point((_ref6 = sample.right) != null ? _ref6.el : void 0, 'cx', 'cy', sample.right);
                move_point(sample != null ? sample.iel : void 0, 'x2', 'y2', sample.right);
                move_point((_ref7 = sample.right) != null ? _ref7.sel : void 0, 'x1', 'y1', sample.right);
                move_point(prev_sample != null ? (_ref8 = prev_sample.right) != null ? _ref8.sel : void 0 : void 0, 'x2', 'y2', sample.right);
              }
              _results.push(prev_sample = sample);
            }
            return _results;
          } else {
            return set_CTM(_this.root, unctm.inverse().translate(point.x - _this.mousedown.origin.x, point.y - _this.mousedown.origin.y));
          }
        }
      });
      stopDrag = function() {
        var _ref;
        if (((_ref = _this.data) != null ? _ref.gaze : void 0) != null) {
          _this.data.gaze.unhighlight();
        }
        _this.mousedrag = false;
        return _this.mousedown = false;
      };
      $(svg).mouseup(function(evt) {
        var sample, _ref;
        if (_this.mousedrag) {
          _this.$svg.removeClass('dragging');
          if (_this.mousedown.index != null) {
            sample = _this.data.gaze.samples[_this.mousedown.index];
            sample.fix();
            _this.$svg.trigger('dirty');
            (_ref = _this.data.gaze).save.apply(_ref, _this.mousedown.row);
          }
        }
        return stopDrag();
      });
      return $(document).keyup(function(evt) {
        if (evt.which === 27) {
          _this.undo.pop();
          return stopDrag();
        }
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
            _this.undo = new UndoStack(_this.data);
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
      var $bb_selected, $gaze_selected, circle_cmenu, fixations, load, load_timer, load_with_delay, opts, set_opts, svg_cmenu,
        _this = this;
      opts = {};
      fixations = null;
      $bb_selected = $();
      $gaze_selected = $();
      load_timer = null;
      set_opts = function() {
        var blink, dispersion, duration, smoothing;
        fixations = $('#i-dt').is(':checked');
        if (fixations) {
          dispersion = parseInt($('#dispersion_n').val(), 10);
          duration = parseInt($('#duration_n').val(), 10);
          blink = parseInt($('#blink_n').val(), 10);
          smoothing = parseInt($('#smoothing_n').val(), 10);
          opts = {
            dispersion: dispersion,
            duration: duration,
            blink: blink,
            smoothing: smoothing
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
      $('#smoothing, #smoothing_n').bind('input', function(evt) {
        return load_with_delay();
      });
      $('#i-dt-options input').bind('input', function(evt) {
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
        $('#smoothing, #smoothing-n').val(fixfix.data.gaze.flags.smoothing);
        $('#fix-options').toggleClass('dirty', !!fixfix.data.gaze.flags.dirty);
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
      circle_cmenu = [
        {
          'ID': {
            onclick: function() {
              return false;
            },
            beforeShow: function(menuitem) {
              var $this, eye, header, index, sample;
              $this = $(this);
              index = $this.data('index');
              eye = $this.data('eye');
              sample = fixfix.data.gaze.samples[index];
              header = "#" + index + " (" + sample.time + " ms) " + eye;
              return menuitem.$element.find('.context-menu-item-inner').text(header);
            },
            disabled: true
          }
        }, $.contextMenu.separator, {
          'Freeze': {
            onclick: function(menuitem, menu, menuevent) {
              var sample;
              sample = fixfix.data.gaze.samples[parseInt($(this).data('index'), 10)];
              sample.fix(!sample.frozen);
              return true;
            },
            title: 'Prevent from being moved automatically',
            beforeShow: function(menuitem) {
              var disabled, from, index, sample, to, _ref;
              index = parseInt($(this).data('index'), 10);
              sample = fixfix.data.gaze.samples[index];
              _ref = fixfix.data.gaze.find_row(index), from = _ref[0], to = _ref[1];
              disabled = index <= from || index >= to;
              menuitem.$element.toggleClass('context-menu-item-disabled', disabled);
              return menuitem.$element.toggleClass('checked', !!sample.frozen);
            }
          }
        }, {
          'Unfreeze Row': {
            onclick: function(menuitem, menu, menuevent) {
              var from, index, to, _i, _ref, _ref1;
              _ref = fixfix.data.gaze.find_row(parseInt($(this).data('index'), 10)), from = _ref[0], to = _ref[1];
              for (index = _i = _ref1 = from + 1; _ref1 <= to ? _i < to : _i > to; index = _ref1 <= to ? ++_i : --_i) {
                fixfix.data.gaze.samples[index].fix(false);
              }
              return true;
            },
            title: 'Unfreeze all points in this row'
          }
        }
      ];
      $(fixfix.svg._svg).contextMenu(circle_cmenu, 'circle');
      svg_cmenu = [
        {
          'Single Mode': {
            onclick: function(menuitem, menu, menuevent) {
              fixfix.single_mode = !fixfix.single_mode;
              return true;
            },
            title: 'Treat all points as frozen, so each operation only affects one',
            beforeShow: function(menuitem) {
              return menuitem.$element.toggleClass('checked', fixfix.single_mode);
            }
          }
        }, {
          'Undo': {
            onclick: function(menuitem, menu, menuevent) {
              var from, to, _ref;
              _ref = fixfix.undo.pop(), from = _ref[0], to = _ref[1];
              fixfix.$svg.trigger('dirty');
              return fixfix.data.gaze.save(from, to);
            },
            title: 'Undo an edit action',
            beforeShow: function(menuitem) {
              var disabled;
              disabled = fixfix.undo.empty();
              return menuitem.$element.toggleClass('context-menu-item-disabled', disabled);
            }
          }
        }
      ];
      $('body').contextMenu(svg_cmenu);
      set_opts();
    }

    return FileBrowser;

  })();

}).call(this);

/*
//@ sourceMappingURL=main.js.map
*/
