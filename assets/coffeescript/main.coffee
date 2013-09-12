# vim: ts=4:sts=4:sw=4

ZOOM_SENSITIVITY = 0.2

# contextMenu
$.contextMenu.shadow = false
$.contextMenu.theme =
    if navigator.platform.match(/Mac/) then "osx"
    else if navigator.platform.match(/Linux/) then "human"
    else if navigator.platform.match(/Win/) then "vista"
    else "default"

# pan/zoom support
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

# tree hierarchy for SVG elements, hoping to speed up layout task
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
        frozen = if @frozen then ' frozen' else ''
        if gaze? and gaze.x? and gaze.y? and gaze.pupil?
            this[eye].el = svg.circle(parent, gaze.x, gaze.y, 3, {
                id: eye[0] + @index
                'data-index': @index
                'data-eye': eye
                class: 'drawn ' + eye + frozen
            })

    render_intereye: (svg, parent) ->
        if @left.x? and @left.y? and @right.x? and @right.y?
            this.iel = svg.line(parent, @left.x, @left.y, @right.x, @right.y, {
                id: 'i' + @index
                'data-index': @index
                class: 'drawn inter'
            })

    render_saccade: (svg, parent, eye, next) ->
        gaze1 = this[eye]
        gaze2 = next[eye]
        if gaze1? and gaze2? and gaze1.x? and gaze1.y? and gaze2.x? and gaze2.y?
            klass = 'drawn ' + eye
            klass += ' rs' if @rs?
            klass += ' blink' if @blink?
            this[eye].sel = svg.line(parent, gaze1.x, gaze1.y, gaze2.x, gaze2.y, {
                id: 's' + eye[0] + @index
                'data-index': @index
                class: klass
            })

    fix: (value = true) ->
        this.frozen = value
        circles = $([this.left?.el, this.center?.el, this.right?.el])
        circles.toggleClass('frozen', value)

class Reading
    constructor: (@samples, @flags, @row_bounds) ->
        for [from, to] in @row_bounds
            @samples[from].frozen = true
            @samples[to].frozen = true

    find_row: (index) ->
        for [from, to] in @row_bounds
            if index <= to
                if index >= from
                    return [from, to]
                break
        return [null, null] # no elements

    toggle_class_on_range: (from, to, klass, onoff) ->
        return unless to? # must have elements

        elements = []
        if (sample = @samples[from - 1])
            for eye in ['left', 'center', 'right']
                if (sample_eye = sample[eye])
                    # first saccade
                    elements.push(sample.sel)
        for index in [from .. to]
            sample = @samples[index]
            elements.push(sample.iel)
            for eye in ['left', 'center', 'right']
                if (sample_eye = sample[eye])
                    # fixations
                    elements.push(sample_eye.el)
                    # saccades, including the return sweeps on each end
                    elements.push(sample_eye.sel)

        $(elements).toggleClass(klass, onoff)

    toggle_class_on_row_of: (index, klass, onoff) ->
        [from, to] = @find_row(index)
        @toggle_class_on_range(from, to, klass, onoff)

    highlight_row_of: (index) ->
        $('.drawn').addClass('faint')
        @toggle_class_on_row_of(index, 'faint', false)

    highlight_range: (from, to) ->
        $('.drawn').addClass('faint')
        @toggle_class_on_range(from, to, 'index', false)

    unhighlight: ->
        $('.faint').removeClass('faint')


class window.FixFix
    constructor: (svg) ->
        @$svg = $(svg)
        @data = {}
        $(@$svg).svg(onLoad: @init)


    init: (@svg) =>
        @root = @svg.group()
        @bb_group = @svg.group(@root, 'bb')
        @gaze_group = @svg.group(@root, 'gaze')
        @single_mode = false

        svg = @svg._svg

        $(svg).mousewheel (evt, delta, dx, dy) =>
            # zoom svg
            ctm = @root.getCTM()
            z = Math.pow(1 + ZOOM_SENSITIVITY, dy / 360)
            p = event_point(svg, evt).matrixTransform(ctm.inverse())
            k = svg.createSVGMatrix().translate(p.x, p.y).scale(z).translate(-p.x, -p.y)
            set_CTM(@root, ctm.multiply(k))
            return false

        $(svg).on('mousedown', (evt) =>
            # possibly initiate move/pan
            node_name = evt.target.nodeName
            unctm = @root.getCTM().inverse()

            switch evt.button
                when 1
                    if node_name == 'circle'
                        # move
                        $target = $(evt.target)
                        index = $target.data('index')
                        @data.gaze.highlight_row_of(index)

                        if @single_mode
                            from = to = index
                        else
                            [from, to] = [row_from, row_to] = @data.gaze.find_row(index)
                            for from in [index .. row_from]
                                break if from == row_from or (from != index and @data.gaze.samples[from].frozen)
                            for to in [index .. row_to]
                                break if to == row_to or (to != index and @data.gaze.samples[to].frozen)

                    else if node_name == 'svg'
                    else
                        return

                    @mousedown =
                        unctm: unctm
                        origin: event_point(svg, evt).matrixTransform(unctm)
                        index: index
                        target: index && evt.target
                        eye: index && $target.data('eye')
                        row: [from, to]
                    @mousedrag = false
        )

        $(svg).mousemove((evt) =>
            if @mousedown
                @mousedrag = true
                # prevent cursor flicker
                @$svg.addClass('dragging')
            if @mousedrag
                unctm = @root.getCTM().inverse()
                point = event_point(svg, evt).matrixTransform(unctm)

                if @mousedown.index?
                    # move the point, applying associated changes
                    eye = @mousedown.eye

                    [from, to] = @mousedown.row
                    sample = @data.gaze.samples[@mousedown.index]
                    point_delta =
                        x: point.x - sample[eye].x
                        y: point.y - sample[eye].y
                    extent = from - @mousedown.index
                    a_x = -point_delta.x / (extent * extent)
                    a_y = -point_delta.y / (extent * extent)
                    prev_sample = @data.gaze.samples[from - 1]
                    for index in [from .. to]
                        sample = @data.gaze.samples[index]
                        index_diff = index - @mousedown.index
                        if index_diff == 0
                            extent = to - @mousedown.index
                            a_x = -point_delta.x / (extent * extent)
                            a_y = -point_delta.y / (extent * extent)
                            delta = point_delta
                        else
                            delta =
                                x: a_x * index_diff * index_diff + point_delta.x
                                y: a_y * index_diff * index_diff + point_delta.y

                        sample[eye].x += delta.x
                        sample[eye].y += delta.y
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

                        prev_sample = sample
                else
                    # pan the view
                    set_CTM(@root,
                            unctm.
                                inverse().
                                translate(
                                    point.x - @mousedown.origin.x,
                                    point.y - @mousedown.origin.y)
                    )
        )

        $(svg).mouseup((evt) =>
            if @mousedrag
                @$svg.removeClass('dragging')

                if @mousedown.index?
                    # it was a move
                    sample = @data.gaze.samples[@mousedown.index]
                    sample.fix()
                    @$svg.trigger('dirty')

                    # save
                    changes = []
                    [from, to] = @mousedown.row
                    for index in [from .. to]
                        sample = @data.gaze.samples[index]
                        changes.push({
                            index: index
                            lx: sample.left.x
                            ly: sample.left.y
                            rx: sample.right.x
                            ry: sample.right.y
                        })

                    payload =
                        file: @data.gaze.opts.file
                        changes: JSON.stringify(changes)

                    $.ajax
                        url: 'change'
                        type: 'post'
                        data: payload

            if @data?.gaze?
                @data.gaze.unhighlight()

            @mousedrag = false
            @mousedown = false
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
                    for sample, index in @data.gaze.samples
                        sample.index = index
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
                    sample.render_intereye(@svg, parent)
        for eye of @data.gaze.opts.eyes
            if @data.gaze.opts.eyes[eye]
                if @data.gaze.flags.lines
                    treedraw @svg, @svg.group(@gaze_group), samples.length - 1, tree_factor, (parent, index) =>
                        sample1 = samples[index]
                        sample2 = samples[index + 1]
                        if sample1? and sample2?
                            sample1.render_saccade(@svg, parent, eye, sample2)
                treedraw @svg, @svg.group(@gaze_group), samples.length, tree_factor, (parent, index) =>
                    sample = samples[index]
                    if sample?
                        sample.render(@svg, parent, eye)


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
                smoothing = parseInt($('#smoothing_n').val(), 10)
                opts =
                    dispersion: dispersion
                    duration: duration
                    blink: blink
                    smoothing: smoothing
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

        $('#smoothing, #smoothing_n').bind('input', (evt) ->
            load_with_delay()
        )
        $('#i-dt-options input').bind('input', (evt) ->
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

        fixfix.$svg.on('loaded', (evt) =>
            fixation_opts = fixfix.data.gaze.flags.fixation
            $('#i-dt').prop('checked', !!fixation_opts)
            if fixation_opts
                for key, value of fixation_opts
                    $("##{key}, ##{key}-n").val(value)
            $('#smoothing, #smoothing-n').val(fixfix.data.gaze.flags.smoothing)
            $('#fix-options').toggleClass('dirty', !!fixfix.data.gaze.flags.dirty)
            $('#tsv-link').attr('href', "dl#{@gaze_file}")
            $('#download').css('display', 'block')
        )

        fixfix.$svg.on('dirty', (evt) ->
            $('#fix-options').addClass('dirty')
        )
        $('#scrap-changes-btn').click (evt) =>
            load()
            fixfix.$svg.trigger('clean')

        circle_cmenu = [
            {'Freeze': {
                onclick: (menuitem, menu, menuevent) ->
                    sample = fixfix.data.gaze.samples[parseInt($(this).data('index'), 10)]
                    sample.fix(!sample.frozen)
                    true
                title: 'Prevent from being moved automatically'
                beforeShow: (menuitem) ->
                    index = parseInt($(this).data('index'), 10)
                    sample = fixfix.data.gaze.samples[index]
                    [from, to] = fixfix.data.gaze.find_row(index)
                    disabled = index <= from or index >= to
                    menuitem.$element.toggleClass('context-menu-item-disabled', disabled)
                    menuitem.$element.toggleClass('checked', !!sample.frozen)
            }},
            {'Unfreeze Row': {
                onclick: (menuitem, menu, menuevent) ->
                    [from, to] = fixfix.data.gaze.find_row(parseInt($(this).data('index'), 10))
                    for index in [from + 1 ... to]
                        fixfix.data.gaze.samples[index].fix(false)
                    true
                title: 'Unfreeze all points in this row'
            }},
        ]
        $(fixfix.svg._svg).contextMenu(circle_cmenu, 'circle')

        svg_cmenu = [
            {'Single Mode': {
                onclick: (menuitem, menu, menuevent) ->
                    fixfix.single_mode = !fixfix.single_mode
                    true
                title: 'Treat all points as frozen, so each operation only affects one'
                beforeShow: (menuitem) ->
                    menuitem.$element.toggleClass('checked', fixfix.single_mode)
            }},
        ]
        $('body').contextMenu(svg_cmenu)

        set_opts()
