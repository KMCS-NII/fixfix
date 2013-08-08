# vim: ts=4:sts=4:sw=4

class Word
    constructor: (@word, @left, @top, @right, @bottom) ->

    render_box: (svg, parent) ->
        svg.rect(parent, @left, @top, @right - @left, @bottom - @top)

    render_word: (svg, parent) ->
        svg.text(parent, (@left + @right) / 2, (@top + @bottom) / 2, @word, {
            fontSize: @bottom - @top
        })

class Gaze
    constructor: (@x, @y, @pupil, @validity) ->

class Sample
    constructor: (args...) ->
        @left = new Gaze(args[0...4]...)
        @right = new Gaze(args[4...8]...)
        @avg = new Gaze(args[8...12]...)
        @time = args[13]
        switch args[14]
            when 'f' then @first = true
            when 'l' then @last = true
            when 't' then @first = @last = true

    render: (svg, parent, eye) ->
        gaze = this[eye]
        svg.circle(parent, gaze.x, gaze.y, gaze.pupil, {
            class: eye
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
                # arrays in an array are our objects
                if $.isArray(this) and $.isArray(v)
                    if v.length == 5
                        new Word(v...)
                    else
                        new Sample(v...)
                else
                    return v
        ).then (@data) =>
            @render()


    render: ->
        @svg.clear()
        @render_bb()
        @render_gaze(true)

    render_bb: ->
        bb_group = @svg.group('bb')

        word_group = @svg.group(bb_group, 'text')
        for word in @data.bb
            word.render_box(@svg, bb_group)

        text_group = @svg.group(bb_group, 'text')
        for word in @data.bb
            word.render_word(@svg, bb_group)

    render_gaze: (both_eyes) ->
        window.gaze = @data.gaze
        gaze_group = @svg.group('gaze')

        # left and right eye underneath the average
        if both_eyes
            for sample in @data.gaze
                if sample?
                    sample.render(@svg, gaze_group, 'left')
                    sample.render(@svg, gaze_group, 'right')

        # average on top
        for sample in @data.gaze
            if sample?
                sample.render(@svg, gaze_group, 'avg')


class window.FileBrowser
    constructor: (fixfix, bb_browser, gaze_browser) ->
        $(bb_browser).fileTree {
                script: 'files/bb'
                multiFolder: false,
            },
            (@bb_file) ->
        $(gaze_browser).fileTree {
            script: 'files/tsv'
            multiFolder: false,
            },
            (@gaze_file) ->
                fixfix.load(@bb_file, gaze_file)
