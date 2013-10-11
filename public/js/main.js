(function() {
  var EditAction, Gaze, MoveAction, Reading, Sample, ScaleAction, UndoStack, Word, event_point, move_point, set_CTM, treedraw, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

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
        this.selection = {
          start: null,
          end: null
        };
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

    Reading.prototype.get_selection = function(force) {
      var to;
      if (this.selection.start || this.selection.end || force) {
        return {
          start: this.selection.start || 0,
          end: to = this.selection.end || (this.samples.length - 1)
        };
      } else {
        return null;
      }
    };

    Reading.prototype.unhighlight = function() {
      var selection;
      $('.highlight').removeClass('highlight');
      if ((selection = this.get_selection())) {
        $('#gaze').addClass('faint');
        return this.highlight_range(selection.start, selection.end);
      } else {
        return $('#gaze').removeClass('faint');
      }
    };

    Reading.prototype.save = function(from, to) {
      var changes, index, payload, sample, _i;
      if (to < from) {
        return;
      }
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

  EditAction = (function() {
    function EditAction() {}

    return EditAction;

  })();

  MoveAction = (function(_super) {
    __extends(MoveAction, _super);

    function MoveAction(data, from, to, index) {
      var sample, _i, _ref, _ref1;
      this.data = data;
      this.from = from;
      this.to = to;
      this.index = index;
      this.records = [];
      for (index = _i = _ref = this.from, _ref1 = this.to; _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; index = _ref <= _ref1 ? ++_i : --_i) {
        sample = this.data.gaze.samples[index];
        this.records.push([sample.left.x, sample.left.y, sample.center.x, sample.center.y, sample.right.x, sample.right.y]);
      }
    }

    MoveAction.prototype.restore = function() {
      var eye, index, last_sample, sample, _i, _j, _len, _ref, _ref1, _ref2, _ref3, _ref4, _ref5;
      for (index = _i = _ref = this.from, _ref1 = this.to; _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; index = _ref <= _ref1 ? ++_i : --_i) {
        sample = this.data.gaze.samples[index];
        _ref2 = this.records.shift(), sample.left.x = _ref2[0], sample.left.y = _ref2[1], sample.center.x = _ref2[2], sample.center.y = _ref2[3], sample.right.x = _ref2[4], sample.right.y = _ref2[5];
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

    return MoveAction;

  })(EditAction);

  ScaleAction = (function(_super) {
    __extends(ScaleAction, _super);

    function ScaleAction() {
      _ref = ScaleAction.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    return ScaleAction;

  })(MoveAction);

  UndoStack = (function() {
    function UndoStack() {
      this.stack = [];
    }

    UndoStack.prototype.push = function(action) {
      return this.stack.push(action);
    };

    UndoStack.prototype.pop = function() {
      return this.stack.pop().restore();
    };

    UndoStack.prototype.peek = function() {
      return this.stack[this.stack.length - 1];
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
      this.undo = new UndoStack();
      this.mode = null;
    }

    FixFix.prototype.init = function(svg) {
      var arrow, mh, mw, stop_drag,
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
        z = Math.pow(5, dy / 180);
        p = event_point(svg, evt).matrixTransform(ctm.inverse());
        k = svg.createSVGMatrix().translate(p.x, p.y).scale(z).translate(-p.x, -p.y);
        set_CTM(_this.root, ctm.multiply(k));
        return false;
      });
      $(svg).on('mousedown', function(evt) {
        var $target, action, from, index, node_name, row_from, row_to, to, unctm, _i, _j, _ref1, _ref2;
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
                _ref2 = (_ref1 = _this.data.gaze.find_row(index), row_from = _ref1[0], row_to = _ref1[1], _ref1), from = _ref2[0], to = _ref2[1];
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
              action = new MoveAction(_this.data, from, to, index);
              _this.undo.push(action);
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
        var a_x, a_y, delta, extent, eye, from, index, index_diff, point, point_delta, prev_sample, sample, to, unctm, _i, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
        if (_this.mousedown) {
          _this.mousedrag = true;
          _this.$svg.addClass('dragging');
        }
        if (_this.mousedrag) {
          unctm = _this.root.getCTM().inverse();
          point = event_point(svg, evt).matrixTransform(unctm);
          if (_this.mousedown.index != null) {
            eye = _this.mousedown.eye;
            _ref1 = _this.mousedown.row, from = _ref1[0], to = _ref1[1];
            sample = _this.data.gaze.samples[_this.mousedown.index];
            point_delta = {
              x: point.x - sample[eye].x,
              y: point.y - sample[eye].y
            };
            extent = from - _this.mousedown.index;
            a_x = -point_delta.x / (extent * extent);
            a_y = -point_delta.y / (extent * extent);
            prev_sample = _this.data.gaze.samples[from - 1];
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
                move_point((_ref2 = sample.center) != null ? _ref2.el : void 0, 'cx', 'cy', sample.center);
                move_point((_ref3 = sample.center) != null ? _ref3.sel : void 0, 'x1', 'y1', sample.center);
                move_point(prev_sample != null ? (_ref4 = prev_sample.center) != null ? _ref4.sel : void 0 : void 0, 'x2', 'y2', sample.center);
              }
              if (sample.left && eye !== 'right') {
                move_point((_ref5 = sample.left) != null ? _ref5.el : void 0, 'cx', 'cy', sample.left);
                move_point(sample != null ? sample.iel : void 0, 'x1', 'y1', sample.left);
                move_point((_ref6 = sample.left) != null ? _ref6.sel : void 0, 'x1', 'y1', sample.left);
                move_point(prev_sample != null ? prev_sample.left.sel : void 0, 'x2', 'y2', sample.left);
              }
              if (sample.right && eye !== 'left') {
                move_point((_ref7 = sample.right) != null ? _ref7.el : void 0, 'cx', 'cy', sample.right);
                move_point(sample != null ? sample.iel : void 0, 'x2', 'y2', sample.right);
                move_point((_ref8 = sample.right) != null ? _ref8.sel : void 0, 'x1', 'y1', sample.right);
                move_point(prev_sample != null ? (_ref9 = prev_sample.right) != null ? _ref9.sel : void 0 : void 0, 'x2', 'y2', sample.right);
              }
              prev_sample = sample;
            }
            return sample = _this.data.gaze.samples[_this.mousedown.index];
          } else {
            return set_CTM(_this.root, unctm.inverse().translate(point.x - _this.mousedown.origin.x, point.y - _this.mousedown.origin.y));
          }
        }
      });
      stop_drag = function() {
        var _ref1;
        if (((_ref1 = _this.data) != null ? _ref1.gaze : void 0) != null) {
          _this.data.gaze.unhighlight();
        }
        _this.mousedrag = false;
        return _this.mousedown = false;
      };
      $(svg).mouseup(function(evt) {
        var sample, _ref1;
        if (_this.mousedrag) {
          _this.$svg.removeClass('dragging');
          if (_this.mousedown.index != null) {
            sample = _this.data.gaze.samples[_this.mousedown.index];
            sample.fix();
            _this.$svg.trigger('dirty');
            (_ref1 = _this.data.gaze).save.apply(_ref1, _this.mousedown.row);
          }
        }
        return stop_drag();
      });
      return $(document).keyup(function(evt) {
        if (_this.mousedrag && evt.which === 27) {
          _this.undo.pop();
          return stop_drag();
        }
      });
    };

    FixFix.prototype.scale_selection = function(moved_index, scale_index, affect_x, affect_y) {
      var delta_center_x, delta_center_y, delta_left_x, delta_left_y, delta_right_x, delta_right_y, eye, index, last_sample, last_undo, move_info, moved_sample, sample, scale_delta, scale_sample, selection, _i, _j, _k, _len, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7;
      selection = this.data.gaze.get_selection(true);
      last_undo = this.undo.peek();
      moved_sample = this.data.gaze.samples[last_undo.index];
      move_info = last_undo.records[last_undo.index - last_undo.from];
      delta_left_x = move_info[0] - moved_sample.left.x;
      delta_left_y = move_info[1] - moved_sample.left.y;
      delta_center_x = move_info[2] - moved_sample.center.x;
      delta_center_y = move_info[3] - moved_sample.center.y;
      delta_right_x = move_info[4] - moved_sample.right.x;
      delta_right_y = move_info[5] - moved_sample.right.y;
      this.undo.pop();
      this.undo.push(new ScaleAction(this.data, selection.start, selection.end, moved_index));
      scale_sample = scale_index != null ? this.data.gaze.samples[scale_index] : null;
      scale_delta = function(orig_value, moved_orig_value, scale_point_orig_value, delta_at_moved_point) {
        var scale_factor;
        scale_factor = scale_point_orig_value ? (orig_value - scale_point_orig_value) / (moved_orig_value - scale_point_orig_value) : 1;
        return delta_at_moved_point * scale_factor;
      };
      for (index = _i = _ref1 = selection.start, _ref2 = selection.end; _ref1 <= _ref2 ? _i <= _ref2 : _i >= _ref2; index = _ref1 <= _ref2 ? ++_i : --_i) {
        sample = this.data.gaze.samples[index];
        if (affect_x) {
          sample.left.x -= scale_delta(sample.left.x, moved_sample.left.x, scale_sample && scale_sample.left.x, delta_left_x);
          sample.center.x -= scale_delta(sample.center.x, moved_sample.center.x, scale_sample && scale_sample.center.x, delta_center_x);
          sample.right.x -= scale_delta(sample.right.x, moved_sample.right.x, scale_sample && scale_sample.right.x, delta_right_x);
        }
        if (affect_y) {
          sample.left.y -= scale_delta(sample.left.y, moved_sample.left.y, scale_sample && scale_sample.left.y, delta_left_y);
          sample.center.y -= scale_delta(sample.center.y, moved_sample.center.y, scale_sample && scale_sample.center.y, delta_center_y);
          sample.right.y -= scale_delta(sample.right.y, moved_sample.right.y, scale_sample && scale_sample.right.y, delta_right_y);
        }
      }
      last_sample = this.data.gaze.samples[selection.start - 1];
      for (index = _j = _ref3 = selection.start, _ref4 = selection.end; _ref3 <= _ref4 ? _j <= _ref4 : _j >= _ref4; index = _ref3 <= _ref4 ? ++_j : --_j) {
        sample = this.data.gaze.samples[index];
        _ref5 = ['left', 'center', 'right'];
        for (_k = 0, _len = _ref5.length; _k < _len; _k++) {
          eye = _ref5[_k];
          if ((_ref6 = sample[eye]) != null ? _ref6.el : void 0) {
            sample[eye].el.setAttribute('cx', sample[eye].x);
            sample[eye].el.setAttribute('cy', sample[eye].y);
          }
          if (sample[eye].sel) {
            sample[eye].sel.setAttribute('x1', sample[eye].x);
            sample[eye].sel.setAttribute('y1', sample[eye].y);
          }
          if (last_sample && ((_ref7 = last_sample[eye]) != null ? _ref7.sel : void 0)) {
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
        last_sample = sample;
      }
      this.$svg.trigger('dirty');
      this.data.gaze.save(selection.start, selection.end);
      return this.scale_point = moved_index;
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
        var index, sample, _i, _j, _len, _len1, _ref1, _ref2;
        _this.data[type] = data;
        _this.data[type].opts = opts;
        switch (type) {
          case 'bb':
            return _this.render_bb();
          case 'gaze':
            if (_this.data.gaze.flags.center) {
              _ref1 = _this.data.gaze.samples;
              for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
                sample = _ref1[_i];
                sample.build_center();
              }
            }
            _ref2 = _this.data.gaze.samples;
            for (index = _j = 0, _len1 = _ref2.length; _j < _len1; index = ++_j) {
              sample = _ref2[index];
              sample.index = index;
            }
            _this.render_gaze();
            _this.undo = new UndoStack();
            return _this.$svg.trigger('loaded');
        }
      });
      return delete opts.cache;
    };

    FixFix.prototype.render_bb = function() {
      var text_group, word, word_group, _i, _j, _len, _len1, _ref1, _ref2, _results;
      $(this.bb_group).empty();
      word_group = this.svg.group(this.bb_group, 'text');
      _ref1 = this.data.bb;
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        word = _ref1[_i];
        word.render_box(this.svg, word_group);
      }
      text_group = this.svg.group(this.bb_group, 'text');
      _ref2 = this.data.bb;
      _results = [];
      for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
        word = _ref2[_j];
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
      $(fixfix.svg._svg).contextMenu({
        selector: 'circle',
        animation: {
          duration: 0
        },
        build: function($trigger, evt) {
          var eye, from, index, items, sample, to, _ref1;
          index = $trigger.data('index');
          eye = $trigger.data('eye');
          sample = fixfix.data.gaze.samples[index];
          _ref1 = fixfix.data.gaze.find_row(index), from = _ref1[0], to = _ref1[1];
          items = {
            header: {
              name: "#" + index + " " + eye + " (" + sample.time + " ms)",
              className: "header",
              disabled: true
            },
            frozen: {
              name: "Frozen",
              disabled: index <= from || index >= to,
              icon: sample.frozen ? "checkmark" : void 0,
              callback: function(key, options) {
                return sample.fix(!sample.frozen);
              }
            },
            unfreeze_row: {
              name: "Unfreeze Row",
              callback: function(key, options) {
                var _i, _ref2, _results;
                _results = [];
                for (index = _i = _ref2 = from + 1; _ref2 <= to ? _i < to : _i > to; index = _ref2 <= to ? ++_i : --_i) {
                  _results.push(fixfix.data.gaze.samples[index].fix(false));
                }
                return _results;
              }
            },
            separator1: "----------",
            select_start: {
              name: "Selection Start",
              callback: function(key, options) {
                fixfix.data.gaze.selection.start = index;
                return fixfix.data.gaze.unhighlight();
              }
            },
            select_end: {
              name: "Selection End",
              callback: function(key, options) {
                fixfix.data.gaze.selection.end = index;
                return fixfix.data.gaze.unhighlight();
              }
            },
            scale_point: {
              name: "Scale Point",
              callback: function(key, options) {
                return fixfix.scale_point = index;
              }
            }
          };
          return {
            items: items
          };
        }
      });
      $.contextMenu({
        selector: 'body',
        animation: {
          duration: 0
        },
        build: function($trigger, evt) {
          var items, last_undo, move_present, _ref1, _ref2;
          last_undo = fixfix.undo.peek();
          move_present = last_undo && (last_undo.constructor === MoveAction);
          items = {
            single: {
              name: "Single mode",
              icon: fixfix.single_mode ? "checkmark" : void 0,
              callback: function(key, options) {
                fixfix.single_mode = !fixfix.single_mode;
                return true;
              }
            },
            undo: {
              name: "Undo",
              disabled: fixfix.undo.empty(),
              callback: function(key, options) {
                var from, to, _ref1;
                _ref1 = fixfix.undo.pop(), from = _ref1[0], to = _ref1[1];
                fixfix.$svg.trigger('dirty');
                return fixfix.data.gaze.save(from, to);
              }
            },
            mode_sep: "----------",
            move: {
              name: "Move",
              disabled: !move_present,
              callback: function(key, options) {
                return fixfix.scale_selection(last_undo.index, null, true, true);
              }
            },
            scale: {
              name: "Scale",
              disabled: !((fixfix.scale_point != null) && move_present && fixfix.scale_point !== last_undo.index),
              callback: function(key, options) {
                return fixfix.scale_selection(last_undo.index, fixfix.scale_point, true, true);
              }
            },
            select_clear: {
              name: "Selection Clear",
              disabled: !(fixfix != null ? (_ref1 = fixfix.data) != null ? (_ref2 = _ref1.gaze) != null ? _ref2.get_selection() : void 0 : void 0 : void 0),
              callback: function(key, options) {
                fixfix.data.gaze.selection = {
                  start: null,
                  end: null
                };
                return fixfix.data.gaze.unhighlight();
              }
            }
          };
          return {
            items: items
          };
        }
      });
      set_opts();
    }

    return FileBrowser;

  })();

}).call(this);

/*
//@ sourceMappingURL=main.js.map
*/
