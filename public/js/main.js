(function() {
  window.FixFix = (function() {
    function FixFix(svg) {
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
        data: {
          bb: bb_file,
          gaze: gaze_file
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
      var word, _i, _len, _ref, _results;
      _ref = this.data.bb;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        word = _ref[_i];
        _results.push(console.log(word));
      }
      return _results;
    };

    return FixFix;

  })();

}).call(this);

/*
//@ sourceMappingURL=main.js.map
*/
