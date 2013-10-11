/*! Copyright (c) 2013 Brandon Aaron (http://brandonaaron.net)
 * Licensed under the MIT License (LICENSE.txt).
 *
 * Thanks to: http://adomas.org/javascript-mouse-wheel/ for some pointers.
 * Thanks to: Mathias Bank(http://www.mathias-bank.de) for a scope bug fix.
 * Thanks to: Seamus Leahy for adding deltaX and deltaY
 *
 * Version: 3.1.3
 *
 * Requires: 1.2.2+
 */

(function (factory) {
    if ( typeof define === 'function' && define.amd ) {
        // AMD. Register as an anonymous module.
        define(['jquery'], factory);
    } else if (typeof exports === 'object') {
        // Node/CommonJS style for Browserify
        module.exports = factory;
    } else {
        // Browser globals
        factory(jQuery);
    }
}(function ($) {

    var toFix = ['wheel', 'mousewheel', 'DOMMouseScroll', 'MozMousePixelScroll'];
    var toBind = 'onwheel' in document || document.documentMode >= 9 ? ['wheel'] : ['mousewheel', 'DomMouseScroll', 'MozMousePixelScroll'];
    var lowestDelta, lowestDeltaXY;

    var isMacWebkit = (navigator.userAgent.indexOf("Macintosh") !== -1 &&
                       navigator.userAgent.indexOf("WebKit") !== -1);
    var isFirefox = (navigator.userAgent.indexOf("Gecko") !== -1);

    if ( $.event.fixHooks ) {
        for ( var i = toFix.length; i; ) {
            $.event.fixHooks[ toFix[--i] ] = $.event.mouseHooks;
        }
    }

    $.event.special.mousewheel = {
        setup: function() {
            if ( this.addEventListener ) {
                for ( var i = toBind.length; i; ) {
                    this.addEventListener( toBind[--i], handler, false );
                }
            } else {
                this.onmousewheel = handler;
            }
        },

        teardown: function() {
            if ( this.removeEventListener ) {
                for ( var i = toBind.length; i; ) {
                    this.removeEventListener( toBind[--i], handler, false );
                }
            } else {
                this.onmousewheel = null;
            }
        }
    };

    $.fn.extend({
        mousewheel: function(fn) {
            return fn ? this.bind("mousewheel", fn) : this.trigger("mousewheel");
        },

        unmousewheel: function(fn) {
            return this.unbind("mousewheel", fn);
        }
    });


    function handler(event) {
        var orgEvent = event || window.event;
        var args = [].slice.call(arguments, 1),
        event = $.event.fix(orgEvent);
        event.type = "mousewheel";

        var deltaX =
            orgEvent.deltaX * -30 ||     // wheel event
            orgEvent.wheelDeltaX / 4 ||  // mousewheel
            0;                           // property not defined
        var deltaY =
            orgEvent.deltaY * -30 ||     // wheel event
            orgEvent.wheelDeltaY / 4 ||  // mousewheel event in Webkit
            (orgEvent.wheelDeltaY === undefined &&      // if there is no 2D property then 
                orgEvent.wheelDelta / 4) ||             // use the 1D wheel property
            orgEvent.detail * -10 ||     // Firefox DOMMouseScroll event
            0;                           // property not defined

        if (isMacWebkit) {
            deltaX /= 30;
            deltaY /= 30;
        }

        if (isFirefox && orgEvent.type !== "DOMMouseScroll")
            orgEvent.target.removeEventListener("DOMMouseScroll", handler, false);

        var delta = deltaY || deltaX;

        // Add event and delta to the front of the arguments
        args.unshift(event, delta, deltaX, deltaY);

        return ($.event.dispatch || $.event.handle).apply(this, args);
    }

}));
