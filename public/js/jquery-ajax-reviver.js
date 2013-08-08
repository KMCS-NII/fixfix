/*
* jQuery Ajax Reviver Plugin - v1.2 - 06/19/2012
* 
* Copyright (c) 2012 "Quickredfox" Francois Lafortune
* Licensed under the same conditions as jQuery itself.
* license: http://jquery.org/license/
* source: https://github.com/quickredfox/jquery-ajax-reviver
* 
*/

(function( $ ) {
  "use strict"
  
  var revive
    , cast
    , add;
  
  if( $.type( $.ajaxSettings.revivers ) !== 'array' )
    $.ajaxSettings.revivers = [];

  cast = function( ) {
    var fns  = []
      , args = Array.prototype.slice.call( arguments )
      , arg;
      if( args.length === 0 ) return fns;
      arg = args.shift();
      switch( $.type( arg ) ){
        case 'function' : fns.push( arg ); break;
        case 'string'   :
          var key = arg
            , fn  = args.shift()
          switch( $.type( fn ) ){
            case 'function' :
              var f = function( k, v ) { return k === key ? fn.call( this, v ) : v; };
              fns.push( f )
            break;
            case 'array' :
              fn.forEach( function( f ){
                fns.push( cast.call(null, key, f )[0] );           
              } )
            break;
            default: throw new Error( 'Argument Error' ); break;
          };
        break;
        case 'array':
          Array.prototype.push.apply( fns, arg );
        break;
        case 'object':
          Object.keys(arg).forEach( function( key ) {
            fns.push( cast.call( null, key, arg[key] )[0] );
          });
        break;
      }
      return fns;
  }
  


  add = function( collection /* ... */ ) {
    var args = Array.prototype.slice.call( arguments )
      , collection = args.shift();
    return Array.prototype.push.apply( collection, cast.apply( null, args ) );
  }
  
  
  // Capture 'json' dataType requests and tack-on revivers if wanted. 
  $.ajaxPrefilter( 'json', function(options, original, xhr) {
    if (original.revivers || options.revivers ) {
      options.revivers = $.ajaxSettings.revivers;
      if( original.revivers !== true ){
        add( options.revivers, original.revivers );        
      };
      var converter = options.converters['text json'];
      return options.converters['text json'] = function( data ) {
        if ($.type(data ) !== 'string') return data;
        if( $.type(converter) === 'function'){
          data = JSON.stringify( converter.call( this, data ) );
        };
        return JSON.parse( data, function( key, value ) {
          var context = this;
          return options.revivers.reduce( function( newvalue, reviver ) {
            return reviver.call( context, key, newvalue );
          }, value );
        });
      };
    }
  });
  
  // Registers new "global" revivers.
  $.ajaxReviver = function(fn) {
    if ($.type(fn) === 'string' && arguments.length === 2) {
      add( $.ajaxSettings.revivers, arguments[0], arguments[1] );
    } else {
      add( $.ajaxSettings.revivers, fn );
    };
    return this; // jQuery best practices.
  };
  $.ajaxReviver.version = '1.0'
  
}).call(this, jQuery);
