class Word
  constructor: (@word, @left, @top, @right, @bottom) ->

  render_box: (svg, parent) ->
    svg.rect(parent, @left, @top, @right - @left, @bottom - @top)

  render_word: (svg, parent) ->
    svg.text(parent, (@left + @right) / 2, (@top + @bottom) / 2, @word, {
      fontSize: @bottom - @top
    })

class window.FixFix
  constructor: (svg) ->
    @$svg = $(svg)
    $(@$svg).svg(onLoad: @init)

  init: (@svg) =>

  load: (bb_file, gaze_file) ->
    ($.ajax
      url: 'data.json'
      dataType: 'json'
      data:
        bb: bb_file
        gaze: gaze_file
      revivers: (k, v) ->
        # arrays in array are actually Words
        if $.isArray(this) and $.isArray(v)
          new Word(v...)
        else
          return v
    ).then (@data) =>
      @render()

  file_browser: ->
    $('#bb_browser').fileTree {
        script: 'files/bb'
        multiFolder: false,
      },
      (bb_file) ->
        console.log bb_file
    $('#gaze_browser').fileTree {
        script: 'files/tsv'
        multiFolder: false,
      },
      (gaze_file) ->
        console.log gaze_file

  render: ->
    @render_bb()

  render_bb: ->
    bb_group = @svg.group('bb')

    word_group = @svg.group(bb_group, 'text')
    for word in @data.bb
      word.render_box(@svg, bb_group)

    text_group = @svg.group(bb_group, 'text')
    for word in @data.bb
      word.render_word(@svg, bb_group)
