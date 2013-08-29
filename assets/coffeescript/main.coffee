# vim: ts=4:sts=4:sw=4

ZOOM_SENSITIVITY = 0.2

event_point = (svg, evt) ->
    p = svg.createSVGPoint()
    p.x = evt.clientX
    p.y = evt.clientY
    p

move_point = (element, x_attr, y_attr, point) ->
    if element
        element.setAttribute(x_attr, point.x)
        element.setAttribute(y_attr, point.y)

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

    render: (svg, parent, eye, index) ->
        gaze = this[eye]
        if gaze? and gaze.x? and gaze.y? and gaze.pupil?
            this[eye].el = svg.circle(parent, gaze.x, gaze.y, gaze.pupil, {
                id: eye[0] + index
                'data-index': index
                'data-eye': eye
                class: 'drawn ' + eye
            })

    render_intereye: (svg, parent, index) ->
        if @left.x? and @left.y? and @right.x? and @right.y?
            this.iel = svg.line(parent, @left.x, @left.y, @right.x, @right.y, {
                id: 'lr' + index
                'data-index': index
                class: 'drawn inter'
            })

    render_saccade: (svg, parent, eye, next, index) ->
        gaze1 = this[eye]
        gaze2 = next[eye]
        if gaze1? and gaze2? and gaze1.x? and gaze1.y? and gaze2.x? and gaze2.y?
            klass = 'drawn ' + eye
            klass += ' rs' if @rs?
            this[eye].sel = svg.line(parent, gaze1.x, gaze1.y, gaze2.x, gaze2.y, {
                id: 's' + eye[0] + index
                'data-index': index
                class: klass
            })

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

        svg = @svg._svg

        $(svg).mousewheel (evt, delta, dx, dy) =>
            if evt.altKey || evt.metaKey
                # zoom svg
                ctm = @root.getCTM()
                z = Math.pow(1 + ZOOM_SENSITIVITY, dy / 360)
                p = event_point(svg, evt).matrixTransform(ctm.inverse())
                k = svg.createSVGMatrix().translate(p.x, p.y).scale(z).translate(-p.x, -p.y)
                set_CTM(@root, ctm.multiply(k))
                return false

        $(svg).on('mousedown', 'circle', (evt) =>
            # possibly initiate drag/pan
            unctm = evt.target.getTransformToElement(svg).inverse()
            $target = $(evt.target)
            @mousedown =
                index: $target.data('index')
                target: evt.target
                eye: $target.data('eye')
                origin: event_point(svg, evt).matrixTransform(unctm)
                unctm: unctm
            @mousedrag = false
        )

        $(svg).mousemove((evt) =>
            if @mousedown
                @mousedrag = true
                # prevent cursor flicker
                @$svg.addClass('dragging')
            if @mousedrag
                # move the point, applying associated changes
                index = @mousedown.index
                unctm = @mousedown.target.getTransformToElement(svg).inverse()
                point = event_point(svg, evt).matrixTransform(unctm)
                eye = @mousedown.eye
                sample = @data.gaze.samples[index]
                prev_sample = @data.gaze.samples[index - 1]

                delta =
                    x: point.x - sample[eye].x
                    y: point.y - sample[eye].y
                sample[eye].x = point.x
                sample[eye].y = point.y

                if eye == 'center'
                    sample.left.x += delta.x
                    sample.left.y += delta.y
                    sample.right.x += delta.x
                    sample.right.y += delta.y
                else
                    sample.center.x += delta.x / 2
                    sample.center.y += delta.y / 2

                if sample.center
                    move_point(sample.center?.el, 'cx', 'cy', sample.center)
                    move_point(sample.center?.sel, 'x1', 'y1', sample.center)
                    move_point(prev_sample?.center?.sel, 'x2', 'y2', sample.center)
                if sample.left and eye != 'right'
                    move_point(sample.left?.el, 'cx', 'cy', sample.left)
                    move_point(sample?.iel, 'x1', 'y1', sample.left)
                    move_point(sample.left?.sel, 'x1', 'y1', sample.left)
                    move_point(prev_sample?.left.sel, 'x2', 'y2', sample.left)
                if sample.right and eye != 'left'
                    move_point(sample.right?.el, 'cx', 'cy', sample.right)
                    move_point(sample?.iel, 'x2', 'y2', sample.right)
                    move_point(sample.right?.sel, 'x1', 'y1', sample.right)
                    move_point(prev_sample?.right?.sel, 'x2', 'y2', sample.right)
            # TODO pan
        )

        $(svg).mouseup((evt) =>
            if @mousedrag
                @mousedown = false
                @mousedrag = false
                @$svg.removeClass('dragging')
                @$svg.trigger('dirty')
                # TODO save
        )

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
        if @data.gaze.flags.lines
            treedraw @svg, @svg.group(@gaze_group), samples.length, tree_factor, (parent, index) =>
                sample = samples[index]
                if sample?
                    sample.render_intereye(@svg, parent, index)
        for eye of @data.gaze.opts.eyes
            if @data.gaze.opts.eyes[eye]
                if @data.gaze.flags.lines
                    treedraw @svg, @svg.group(@gaze_group), samples.length - 1, tree_factor, (parent, index) =>
                        sample1 = samples[index]
                        sample2 = samples[index + 1]
                        if sample1? and sample2? and !sample1.blink
                            sample1.render_saccade(@svg, parent, eye, sample2, index)
                treedraw @svg, @svg.group(@gaze_group), samples.length, tree_factor, (parent, index) =>
                    sample = samples[index]
                    if sample?
                        sample.render(@svg, parent, eye, index)


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

        fixfix.$svg.on('loaded', (evt) ->
            fixation_opts = fixfix.data.gaze.flags.fixation
            $('#i-dt').prop('checked', !!fixation_opts)
            if fixation_opts
                for key, value of fixation_opts
                    $("##{key}, ##{key}-n").val(value)
        )

        fixfix.$svg.on('dirty', (evt) ->
            $('#fix-options').addClass('dirty')
        )
        $('#scrap-changes-btn').click (evt) =>
            $('#fix-options').removeClass('dirty')
            load()

        set_opts()
