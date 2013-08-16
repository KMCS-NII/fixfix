(function() {
  var Gaze, Sample, Word,
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
    function Sample(time, left, right) {
      this.time = time;
      this.left = left;
      this.right = right;
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
      _ref = ['left', 'right'];
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
      this.data = {};
      $(this.$svg).svg({
        onLoad: this.init
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
      this.gaze_group = this.svg.group('gaze');
      return this.bb_group = this.svg.group('bb');
    };

    FixFix.prototype.load = function(file, type) {
      var _this = this;
      return ($.ajax({
        url: "" + type + ".json",
        dataType: 'json',
        data: {
          file: file
        },
        revivers: function(k, v) {
          if ((v != null) && typeof v === 'object') {
            if ("word" in v) {
              return new Word(v.word, v.left, v.top, v.right, v.bottom);
            } else if ("validity" in v) {
              return new Gaze(v.x, v.y, v.pupil, v.validity);
            } else if ("time" in v) {
              return new Sample(v.time, v.left, v.right);
            }
          }
          return v;
        }
      })).then(function(data) {
        _this.data[type] = data;
        switch (type) {
          case 'bb':
            return _this.render_bb();
          case 'gaze':
            return _this.render_gaze();
        }
      });
    };

    FixFix.prototype.render_bb = function() {
      var max, min, text_group, word, word_group, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2;
      $(this.bb_group).empty();
      word_group = this.svg.group(this.bb_group, 'text');
      _ref = this.data.bb;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        word = _ref[_i];
        word.render_box(this.svg, word_group);
      }
      text_group = this.svg.group(this.bb_group, 'text');
      _ref1 = this.data.bb;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        word = _ref1[_j];
        word.render_word(this.svg, text_group);
      }
      min = this.data.bb[0].top;
      max = this.data.bb[0].bottom;
      _ref2 = this.data.bb;
      for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
        word = _ref2[_k];
        min = Math.min(min, word.top);
        max = Math.max(max, word.bottom);
      }
      return this.$svg.height(max + min);
    };

    FixFix.prototype.render_gaze = function() {
      var c, m, sample, subgroup, _i, _len, _ref, _results;
      $(this.gaze_group).empty();
      window.gaze = this.data.gaze;
      m = c = 50;
      _ref = this.data.gaze;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        sample = _ref[_i];
        if (c === m) {
          c = 0;
          subgroup = this.svg.group(this.gaze_group);
        } else {
          c += 1;
        }
        if (sample != null) {
          sample.render(this.svg, subgroup, 'left');
          _results.push(sample.render(this.svg, subgroup, 'right'));
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
        $bb_selected.removeClass('selected');
        ($bb_selected = $bb_newly_selected).addClass('selected');
        return fixfix.load(bb_file, 'bb');
      });
      $(gaze_browser).fileTree({
        script: 'files/tsv',
        multiFolder: false
      }, function(gaze_file, $gaze_newly_selected) {
        $gaze_selected.removeClass('selected');
        ($gaze_selected = $gaze_newly_selected).addClass('selected');
        return fixfix.load(gaze_file, 'gaze');
      });
    }

    return FileBrowser;

  })();

}).call(this);

/*
//@ sourceMappingURL=main.js.map
*/
