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
    constructor: (@time, @left, @right) ->

    render: (svg, parent, eye) ->
        gaze = this[eye]
        @el = []
        this[eye].el = svg.circle(parent, gaze.x, gaze.y, gaze.pupil, {
            class: eye
            'data-orig-x': gaze.x
            'data-orig-y': gaze.y
            'data-edit-x': gaze.x + 30
            'data-edit-y': gaze.y + 30
        })

    move_to: (state) ->
        for eye in ['left', 'right']
            el = this[eye].el
            el.setAttribute('cx', el.getAttribute('data-' + state + '-x'))
            el.setAttribute('cy', el.getAttribute('data-' + state + '-y'))

class window.FixFix
    constructor: (svg) ->
        @$svg = $(svg)
        $(@$svg).svg(onLoad: @init)

        # toggle edit/orig position on Shift
        shifted = false
        $(document).keydown (evt) =>
            return unless @data and evt.keyCode == 16
            if evt.shiftKey and not shifted
                for sample in @data.gaze
                    if sample
                        sample.move_to('edit')
                shifted = true
        $(document).keyup (evt) =>
            return unless @data and evt.keyCode == 16
            if not evt.shiftKey and shifted
                for sample in @data.gaze
                    if sample
                        sample.move_to('orig')
                shifted = false

    init: (@svg) =>

    load: (bb_file, gaze_file) ->
        ($.ajax
            url: 'data.json'
            dataType: 'json'
            data:
                bb: bb_file
                gaze: gaze_file
            revivers: (k, v) ->
                if v? and typeof(v) == 'object'
                    if "word" of v
                        return new Word(v.word, v.left, v.top, v.right, v.bottom)
                    else if "validity" of v
                        return new Gaze(v.x, v.y, v.pupil, v.validity)
                    else if "time" of v
                        return new Sample(v.time, v.left, v.right)
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

#        # average on top
#        for sample in @data.gaze
#            if sample?
#                sample.render(@svg, gaze_group, 'avg')


class window.FileBrowser
    $bb_selected = $()
    $gaze_selected = $()
    constructor: (fixfix, bb_browser, gaze_browser) ->
        $(bb_browser).fileTree {
                script: 'files/bb'
                multiFolder: false,
            },
            (@bb_file, $bb_newly_selected) ->
                $bb_selected.removeClass('selected')
                ($bb_selected = $bb_newly_selected).addClass('selected')
        $(gaze_browser).fileTree {
            script: 'files/tsv'
            multiFolder: false,
            },
            (@gaze_file, $gaze_newly_selected) ->
                $gaze_selected.removeClass('selected')
                ($gaze_selected = $gaze_newly_selected).addClass('selected')
                fixfix.load(@bb_file, gaze_file)
