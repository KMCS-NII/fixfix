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
        @data = {}
        $(@$svg).svg(onLoad: @init)

        # sliders
        $('input[type="range"]').change (evt) ->
            $target = $(evt.target)
            $number = $target.next('input[type="number"]')
            if $target? && $number.val() != $target.val()
                $number.val($target.val())
        $('input[type="number"]').change (evt) ->
            $target = $(evt.target)
            $number = $target.prev('input[type="range"]')
            if $number? && $number.val() != $target.val()
                $number.val($target.val())

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
        @gaze_group = @svg.group('gaze')
        @bb_group = @svg.group('bb')

    load: (file, type) ->
        ($.ajax
            url: "#{type}.json"
            dataType: 'json'
            data:
                file: file
            revivers: (k, v) ->
                if v? and typeof(v) == 'object'
                    if "word" of v
                        return new Word(v.word, v.left, v.top, v.right, v.bottom)
                    else if "validity" of v
                        return new Gaze(v.x, v.y, v.pupil, v.validity)
                    else if "time" of v
                        return new Sample(v.time, v.left, v.right)
                return v
        ).then (data) =>
            @data[type] = data
            switch type
                when 'bb' then @render_bb()
                when 'gaze' then @render_gaze()

    render_bb: ->
        $(@bb_group).empty()
        word_group = @svg.group(@bb_group, 'text')
        for word in @data.bb
            word.render_box(@svg, word_group)

        text_group = @svg.group(@bb_group, 'text')
        for word in @data.bb
            word.render_word(@svg, text_group)

        min = @data.bb[0].top
        max = @data.bb[0].bottom
        for word in @data.bb
            min = Math.min(min, word.top)
            max = Math.max(max, word.bottom)
        @$svg.height(max + min)


    render_gaze: ->
        $(@gaze_group).empty()
        window.gaze = @data.gaze
        
        # TODO: make a tree structure, depth depending on number
        m = c = 50
        for sample in @data.gaze
            if c == m
                c = 0
                subgroup = @svg.group(@gaze_group)
            else
                c += 1
            if sample?
                sample.render(@svg, subgroup, 'left')
                sample.render(@svg, subgroup, 'right')

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
            (bb_file, $bb_newly_selected) ->
                $bb_selected.removeClass('selected')
                ($bb_selected = $bb_newly_selected).addClass('selected')
                fixfix.load(bb_file, 'bb')
        $(gaze_browser).fileTree {
            script: 'files/tsv'
            multiFolder: false,
            },
            (gaze_file, $gaze_newly_selected) ->
                $gaze_selected.removeClass('selected')
                ($gaze_selected = $gaze_newly_selected).addClass('selected')
                fixfix.load(gaze_file, 'gaze')
