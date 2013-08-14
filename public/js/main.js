(function() {
  var Gaze, Sample, Word,
    __slice = [].slice,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

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
    function Sample() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      this.left = (function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return Object(result) === result ? result : child;
      })(Gaze, args.slice(0, 4), function(){});
      this.right = (function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return Object(result) === result ? result : child;
      })(Gaze, args.slice(4, 8), function(){});
      this.avg = (function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return Object(result) === result ? result : child;
      })(Gaze, args.slice(8, 12), function(){});
      this.time = args[13];
      switch (args[14]) {
        case 'f':
          this.first = true;
          break;
        case 'l':
          this.last = true;
          break;
        case 't':
          this.first = this.last = true;
      }
    }

    Sample.prototype.render = function(svg, parent, eye) {
      var gaze;
      gaze = this[eye];
      this.el = [];
      return this[eye].el = svg.circle(parent, gaze.x, gaze.y, gaze.pupil, {
        "class": eye,
        'data-orig-x': gaze.x,
        'data-orig-y': gaze.y,
        'data-edit-x': gaze.x + 30,
        'data-edit-y': gaze.y + 30
      });
    };

    Sample.prototype.move_to = function(state) {
      var el, eye, _i, _len, _ref, _results;
      _ref = ['avg', 'left', 'right'];
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        eye = _ref[_i];
        el = this[eye].el;
        el.setAttribute('cx', el.getAttribute('data-' + state + '-x'));
        _results.push(el.setAttribute('cy', el.getAttribute('data-' + state + '-y')));
      }
      return _results;
    };

    return Sample;

  })();

  window.FixFix = (function() {
    function FixFix(svg) {
      this.init = __bind(this.init, this);
      var shifted,
        _this = this;
      this.$svg = $(svg);
      $(this.$svg).svg({
        onLoad: this.init
      });
      shifted = false;
      $(document).keydown(function(evt) {
        var sample, _i, _len, _ref;
        if (!(_this.data && evt.keyCode === 16)) {
          return;
        }
        if (evt.shiftKey && !shifted) {
          _ref = _this.data.gaze;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            sample = _ref[_i];
            if (sample) {
              sample.move_to('edit');
            }
          }
          return shifted = true;
        }
      });
      $(document).keyup(function(evt) {
        var sample, _i, _len, _ref;
        if (!(_this.data && evt.keyCode === 16)) {
          return;
        }
        if (!evt.shiftKey && shifted) {
          _ref = _this.data.gaze;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            sample = _ref[_i];
            if (sample) {
              sample.move_to('orig');
            }
          }
          return shifted = false;
        }
      });
    }

    FixFix.prototype.init = function(svg) {
      this.svg = svg;
    };

    FixFix.prototype.load = function(bb_file, gaze_file) {
      var _this = this;
      return ($.ajax({
        url: 'data.json',
        dataType: 'json',
        data: {
          bb: bb_file,
          gaze: gaze_file
        },
        revivers: function(k, v) {
          if ($.isArray(this) && $.isArray(v)) {
            if (v.length === 5) {
              return (function(func, args, ctor) {
                ctor.prototype = func.prototype;
                var child = new ctor, result = func.apply(child, args);
                return Object(result) === result ? result : child;
              })(Word, v, function(){});
            } else {
              return (function(func, args, ctor) {
                ctor.prototype = func.prototype;
                var child = new ctor, result = func.apply(child, args);
                return Object(result) === result ? result : child;
              })(Sample, v, function(){});
            }
          } else {
            return v;
          }
        }
      })).then(function(data) {
        _this.data = data;
        return _this.render();
      });
    };

    FixFix.prototype.render = function() {
      this.svg.clear();
      this.render_bb();
      return this.render_gaze(true);
    };

    FixFix.prototype.render_bb = function() {
      var bb_group, text_group, word, word_group, _i, _j, _len, _len1, _ref, _ref1, _results;
      bb_group = this.svg.group('bb');
      word_group = this.svg.group(bb_group, 'text');
      _ref = this.data.bb;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        word = _ref[_i];
        word.render_box(this.svg, bb_group);
      }
      text_group = this.svg.group(bb_group, 'text');
      _ref1 = this.data.bb;
      _results = [];
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        word = _ref1[_j];
        _results.push(word.render_word(this.svg, bb_group));
      }
      return _results;
    };

    FixFix.prototype.render_gaze = function(both_eyes) {
      var gaze_group, sample, _i, _j, _len, _len1, _ref, _ref1, _results;
      window.gaze = this.data.gaze;
      gaze_group = this.svg.group('gaze');
      if (both_eyes) {
        _ref = this.data.gaze;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          sample = _ref[_i];
          if (sample != null) {
            sample.render(this.svg, gaze_group, 'left');
            sample.render(this.svg, gaze_group, 'right');
          }
        }
      }
      _ref1 = this.data.gaze;
      _results = [];
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        sample = _ref1[_j];
        if (sample != null) {
          _results.push(sample.render(this.svg, gaze_group, 'avg'));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    return FixFix;

  })();

  window.FileBrowser = (function() {
    var $bb_selected, $gaze_selected;

    $bb_selected = $();

    $gaze_selected = $();

    function FileBrowser(fixfix, bb_browser, gaze_browser) {
      $(bb_browser).fileTree({
        script: 'files/bb',
        multiFolder: false
      }, function(bb_file, $bb_newly_selected) {
        this.bb_file = bb_file;
        $bb_selected.removeClass('selected');
        return ($bb_selected = $bb_newly_selected).addClass('selected');
      });
      $(gaze_browser).fileTree({
        script: 'files/tsv',
        multiFolder: false
      }, function(gaze_file, $gaze_newly_selected) {
        this.gaze_file = gaze_file;
        $gaze_selected.removeClass('selected');
        ($gaze_selected = $gaze_newly_selected).addClass('selected');
        return fixfix.load(this.bb_file, gaze_file);
      });
    }

    return FileBrowser;

  })();

}).call(this);

/*
//@ sourceMappingURL=main.js.map
*/
