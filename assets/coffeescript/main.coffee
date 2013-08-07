class FixFix
  constructor: (svg) ->
    @$svg = $(svg)
    $(@$svg).svg(onLoad: @init)
  init: (@svg) ->
    console.log @svg

window.FixFix = FixFix
