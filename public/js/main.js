(function() {
  var FixFix;

  FixFix = (function() {
    function FixFix(svg) {
      this.$svg = $(svg);
      $(this.$svg).svg({
        onLoad: this.init
      });
    }

    FixFix.prototype.init = function(svg) {
      this.svg = svg;
      return console.log(this.svg);
    };

    return FixFix;

  })();

  window.FixFix = FixFix;

}).call(this);

/*
//@ sourceMappingURL=main.js.map
*/
