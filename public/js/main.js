(function() {
  var Word,
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

  window.FixFix = (function() {
    function FixFix(svg) {
      this.init = __bind(this.init, this);
      this.$svg = $(svg);
      $(this.$svg).svg({
        onLoad: this.init
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
            return (function(func, args, ctor) {
              ctor.prototype = func.prototype;
              var child = new ctor, result = func.apply(child, args);
              return Object(result) === result ? result : child;
            })(Word, v, function(){});
          } else {
            return v;
          }
        }
      })).then(function(data) {
        _this.data = data;
        return _this.render();
      });
    };

    FixFix.prototype.file_browser = function() {
      $('#bb_browser').fileTree({
        script: 'files/bb',
        multiFolder: false
      }, function(bb_file) {
        return console.log(bb_file);
      });
      return $('#gaze_browser').fileTree({
        script: 'files/tsv',
        multiFolder: false
      }, function(gaze_file) {
        return console.log(gaze_file);
      });
    };

    FixFix.prototype.render = function() {
      return this.render_bb();
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

    return FixFix;

  })();

}).call(this);

/*
//@ sourceMappingURL=main.js.map
*/
