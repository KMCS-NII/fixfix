# vim: ts=4:sts=4:sw=4

treedraw = (svg, parent, size, factor, callback) ->
    return unless size
    parents = [parent]
    recurse = (parent, level) ->
        if level > 0
            level -= 1
            for i in [1..factor]
                subparent = if level == 0 then parent else svg.group(parent)
                recurse(subparent, level)
                return unless size
        else
            size -= 1
            callback(parent, size)
    recurse(parent, Math.ceil(Math.log(size) / Math.log(factor)))

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
    constructor: (@time, @rs, @blink, @left, @right) ->

    build_center: ->
        if @left.x? and @left.y? and @right.x? and @right.y?
            @center = new Gaze(
                (@left.x + @right.x) / 2,
                (@left.y + @right.y) / 2,
                (@left.pupil + @right.pupil) / 2,
                if @left.validity > @right.validity then @left.validity else @right.validity
            )

    render: (svg, parent, eye) ->
        gaze = this[eye]
        @el = []
        if gaze? and gaze.x? and gaze.y? and gaze.pupil?
            this[eye].el = svg.circle(parent, gaze.x, gaze.y, gaze.pupil, {
                id: eye[0] + @time
                class: 'drawn ' + eye
                'data-orig-x': gaze.x
                'data-orig-y': gaze.y
                'data-edit-x': gaze.x + 30
                'data-edit-y': gaze.y + 30
            })

    render_intereye: (svg, parent) ->
        if @left.x? and @left.y? and @right.x? and @right.y?
            this.iel = svg.line(parent, @left.x, @left.y, @right.x, @right.y, {
                id: 'lr' + @time
                class: 'drawn inter'
            })

    render_saccade: (svg, parent, eye, next) ->
        gaze1 = this[eye]
        gaze2 = next[eye]
        if gaze1? and gaze2? and gaze1.x? and gaze1.y? and gaze2.x? and gaze2.y?
            klass = 'drawn ' + eye
            klass += ' rs' if @rs?
            this[eye].sel = svg.line(parent, gaze1.x, gaze1.y, gaze2.x, gaze2.y, {
                id: eye[0] + @time + '-' + next.time
                class: klass
            })

    move_to: (state) ->
        for eye in ['left', 'right']
            el = this[eye].el
            if el
                el.setAttribute('cx', el.getAttribute('data-' + state + '-x'))
                el.setAttribute('cy', el.getAttribute('data-' + state + '-y'))

class Reading
    constructor: (@samples, @flags, @row_bounds) ->

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
            return unless @data.gaze and evt.keyCode == 16
            if evt.shiftKey and not shifted
                for sample in @data.gaze.samples
                    if sample
                        sample.move_to('edit')
                shifted = true
        $(document).keyup (evt) =>
            return unless @data.gaze and evt.keyCode == 16
            if not evt.shiftKey and shifted
                for sample in @data.gaze.samples
                    if sample
                        sample.move_to('orig')
                shifted = false

    init: (@svg) =>
        @bb_group = @svg.group('bb')
        @gaze_group = @svg.group('gaze')

    load: (file, type, opts) ->
        opts = opts || {}
        opts.file = file
        ($.ajax
            url: "#{type}.json"
            dataType: 'json'
            data: opts
            revivers: (k, v) ->
                if v? and typeof(v) == 'object'
                    if "word" of v
                        return new Word(v.word, v.left, v.top, v.right, v.bottom)
                    else if "validity" of v
                        return new Gaze(v.x, v.y, v.pupil, v.validity)
                    else if "time" of v
                        return new Sample(v.time, v.rs, v.blink, v.left, v.right)
                    else if "samples" of v
                        return new Reading(v.samples, v.flags, v.row_bounds)
                return v
        ).then (data) =>
            @data[type] = data
            @data[type].opts = opts # TODO return them from AJAX
            switch type
                when 'bb' then @render_bb()
                when 'gaze'
                    if @data.gaze.flags.center
                        for sample in @data.gaze.samples
                            sample.build_center()
                    @render_gaze()

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
        @svg._svg.setAttribute('height', max + min)

    render_gaze: ->
        $(@gaze_group).empty()
        tree_factor = 20
        
        samples = @data.gaze.samples
        eyes = []
        if @data.gaze.opts.separate_eyes
            eyes = ['left', 'right']
        if @data.gaze.flags.center
            eyes.push('center')
        for eye in eyes
            treedraw @svg, @svg.group(@gaze_group), samples.length, tree_factor, (parent, index) =>
                sample = samples[index]
                if sample?
                    sample.render(@svg, parent, eye)
            if @data.gaze.flags.lines
                treedraw @svg, @svg.group(@gaze_group), samples.length - 1, tree_factor, (parent, index) =>
                    sample1 = samples[index]
                    sample2 = samples[index + 1]
                    if sample1? and sample2? and !sample1.blink
                        sample1.render_saccade(@svg, parent, eye, sample2)
        if @data.gaze.flags.lines
            treedraw @svg, @svg.group(@gaze_group), samples.length, tree_factor, (parent, index) =>
                sample = samples[index]
                if sample?
                    sample.render_intereye(@svg, parent)


class window.FileBrowser
    constructor: (fixfix, bb_browser, gaze_browser) ->
        opts = {}
        fixations = null
        $bb_selected = $()
        $gaze_selected = $()
        load_timer = null

        set_opts = ->
            fixations = $('#i-dt').is(':checked')
            if fixations
                dispersion = parseInt($('#dispersion_n').val(), 10)
                duration = parseInt($('#duration_n').val(), 10)
                blink = parseInt($('#blink_n').val(), 10)
                opts =
                    dispersion: dispersion
                    duration: duration
                    blink: blink
            else
                opts = {}
            opts.separate_eyes = $('#separate-eyes').is(':checked')

        $(bb_browser).fileTree {
                script: 'files/bb'
                multiFolder: false,
            },
            (@bb_file, $bb_newly_selected) =>
                $bb_selected.removeClass('selected')
                ($bb_selected = $bb_newly_selected).addClass('selected')
                fixfix.load(bb_file, 'bb')

        $(gaze_browser).fileTree {
            script: 'files/tsv'
            multiFolder: false,
            },
            (@gaze_file, $gaze_newly_selected) =>
                $gaze_selected.removeClass('selected')
                ($gaze_selected = $gaze_newly_selected).addClass('selected')
                fixfix.load(@gaze_file, 'gaze', opts)

        load_handler = (evt) =>
            set_opts()
            if @gaze_file
                clearTimeout(load_timer)
                timeout_handler = =>
                    fixfix.load(@gaze_file, 'gaze', opts)
            load_timer = setTimeout(timeout_handler, 500)
        $('#i-dt-options input[type="range"], #i-dt-options input[type="number"]').bind('input', (evt) ->
            if fixations
                load_handler(evt)
        )
        $('#i-dt, #separate-eyes').click(load_handler)
        set_opts()
