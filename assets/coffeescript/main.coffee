# vim: ts=4:sts=4:sw=4

ZOOM_SENSITIVITY = 0.2

event_point = (svg, evt) ->
    p = svg.createSVGPoint()
    p.x = evt.clientX
    p.y = evt.clientY
    p

set_CTM = (element, matrix) ->
    element.transform.baseVal.initialize(
        element.ownerSVGElement.createSVGTransformFromMatrix(matrix))

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


    init: (@svg) =>
        @root = @svg.group()
        @bb_group = @svg.group(@root, 'bb')
        @gaze_group = @svg.group(@root, 'gaze')

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
            @data[type].opts = opts
            switch type
                when 'bb' then @render_bb()
                when 'gaze'
                    if @data.gaze.flags.center
                        for sample in @data.gaze.samples
                            sample.build_center()
                    @render_gaze()
            @$svg.trigger('loaded')
        delete opts.cache

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

    render_gaze: (opts) ->
        $(@gaze_group).empty()
        tree_factor = 20

        if opts
            @data.gaze.opts = opts
        
        samples = @data.gaze.samples
        # TODO remove flags.center
        for eye of @data.gaze.opts.eyes
            if @data.gaze.opts.eyes[eye]
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

            opts.eyes =
                left: $('#left-eye').is(':checked')
                center: $('#center-eye').is(':checked')
                right: $('#right-eye').is(':checked')

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
                opts.cache = true
                fixfix.load(@gaze_file, 'gaze', opts)

        load = =>
            if @gaze_file
                set_opts()
                fixfix.load(@gaze_file, 'gaze', opts)

        load_with_delay = (evt) =>
            clearTimeout(load_timer)
            load_timer = setTimeout(load, 500)

        $('#i-dt-options input[type="range"], #i-dt-options input[type="number"]').bind('input', (evt) ->
            if fixations
                load_with_delay()
        )
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

        $('#i-dt').click(load)

        # TODO don't redraw things that are already drawn
        $('#eye-options input').click (evt) =>
            if @gaze_file
                set_opts()
                fixfix.render_gaze(opts)

        svg = fixfix.svg._svg
        $(svg).mousewheel (evt, delta, dx, dy) ->
            if evt.metaKey || evt.ctrlKey
                # zoom svg
                ctm = fixfix.root.getCTM()
                z = Math.pow(1 + ZOOM_SENSITIVITY, dy / 360)
                p = event_point(svg, evt).matrixTransform(ctm.inverse())
                k = svg.createSVGMatrix().translate(p.x, p.y).scale(z).translate(-p.x, -p.y)
                set_CTM(fixfix.root, ctm.multiply(k))
                return false

        fixfix.$svg.on('loaded', (evt) ->
            fixation_opts = fixfix.data.gaze.flags.fixation
            $('#i-dt').prop('checked', !!fixation_opts)
            if fixation_opts
                for key, value of fixation_opts
                    $("##{key}, ##{key}-n").val(value)
        )

        set_opts()
