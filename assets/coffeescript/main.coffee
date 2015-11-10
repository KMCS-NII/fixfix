# vim: ts=4:sts=4:sw=4

display_samples = 1500

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
treedraw = (svg, parent, start, end, factor, callback) ->
    return if start == end
    recurse = (parent, level) ->
        if level > 0
            level -= 1
            for i in [1..factor]
                subparent = if level == 0 then parent else svg.group(parent)
                recurse(subparent, level)
                return if start == end
        else
            end -= 1
            callback(parent, end)
    recurse(parent, Math.ceil(Math.log(end - start) / Math.log(factor)))



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
    constructor: (@time, @rs, @blink, @left, @right, @duration, @start, @end) ->

    build_center: ->
        if @left.x? and @left.y? and @right.x? and @right.y?
            @center = new Gaze(
                (@left.x + @right.x) / 2,
                (@left.y + @right.y) / 2, (@left.pupil + @right.pupil) / 2, if @left.validity > @right.validity then @left.validity else @right.validity
            )

    render: (svg, parent, eye) ->
        gaze = this[eye]
        frozen = if @frozen then ' frozen' else ''
        if gaze? and gaze.x? and gaze.y?
            this[eye].el = svg.circle parent, gaze.x, gaze.y, 3,
                id: eye[0] + @index
                'data-index': @index
                'data-eye': eye
                class: 'drawn ' + eye + frozen

    render_intereye: (svg, parent) ->
        if @left.x? and @left.y? and @right.x? and @right.y?
            this.iel = svg.line parent, @left.x, @left.y, @right.x, @right.y,
                id: 'i' + @index
                'data-index': @index
                class: 'drawn inter'

    render_saccade: (svg, parent, eye, next) ->
        gaze1 = this[eye]
        gaze2 = next[eye]
        if gaze1? and gaze2? and gaze1.x? and gaze1.y? and gaze2.x? and gaze2.y?
            klass = 'saccade drawn ' + eye
            klass += ' rs' if @rs?
            klass += ' blink' if @blink?
            this[eye].sel = svg.line parent, gaze1.x, gaze1.y, gaze2.x, gaze2.y,
                id: 's' + eye[0] + @index
                'data-index': @index
                'data-eye': eye
                class: klass

    render_reference: (svg, parent, eye) ->
        if (gaze_ref = @reference?[eye])
            this[eye].xel = svg.circle parent, gaze_ref.x, gaze_ref.y, 2,
                id: 'x' + eye[0] + @index
                'data-index': @index
                'data-eye': eye
                class: 'reference drawn ' + eye

    render_reference_line: (svg, parent, eye) ->
        gaze = this[eye]
        if (gaze_ref = @reference?[eye])
            this[eye].lxel = svg.line parent, gaze.x, gaze.y, gaze_ref.x, gaze_ref.y,
                id: 'lx' + eye[0] + @index
                'data-index': @index
                'data-eye': eye
                class: 'reference drawn ' + eye


    fix: (value = true) ->
        this.frozen = value
        circles = $([this.left?.el, this.center?.el, this.right?.el])
        circles.toggleClass('frozen', value)


class Selection
    constructor: (@reading) -> # half a second default jump
        @clear()

    clear: ->
        # start/end are sample#
        @start = null
        @end = null
        @span = null
        @offset = null

    set_start: (start) ->
        @start = start
        @update_span()
    set_end: (end) ->
        @end = end
        @update_span()
    set_start_end_time: (start_time, end_time) ->
        if start_time != null
            @start = @binary_search_sample(start_time)
        if end_time != null
            @end = @binary_search_sample(end_time)
        @update_span()
    get_start: -> @start || 0
    get_end: -> if @end? then @end else @reading.samples.length - 1
    valid: ->
        return @start? or @end?
    update_span: ->
        if @valid()
            @offset = @reading.samples[@get_start()].time
            end_time = @reading.samples[@get_end()].time
            @span = end_time - @offset

    find_closest_sample: (index, offset, direction) ->
        cur_sample = @reading.samples[index]
        # find the sandwiching samples
        while (prev_sample = cur_sample; cur_sample = @reading.samples[index + direction]) and
                !(offset * direction < cur_sample.time * direction)
            index += direction
        # choose the closer one
        if cur_sample and (offset - prev_sample.time) * direction > (cur_sample.time - offset) * direction
            index += direction
        index
    next: (direction, jump) ->
        return unless @valid()
        @offset += jump * direction
        @start = @find_closest_sample(@get_start(), @offset, direction)
        @end = @find_closest_sample(@get_end(), @offset + @span, direction)
        @reading.unhighlight()

    binary_search_sample: (time, start = 0, end = @reading.samples.length - 1) ->
        mid = ((start + end) / 2)|0
        if end - start == 1
            if time - @reading.samples[start].time < @reading.samples[end].time - time
                start
            else
                end
        else if time < @reading.samples[mid].time
            @binary_search_sample(time, start, mid)
        else
            @binary_search_sample(time, mid, end)


class Reading
    constructor: (@samples, @flags, @row_bounds) ->
        for [from, to] in @row_bounds
            @samples[from].frozen = true
            @samples[to].frozen = true
        @selection = new Selection(this)

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
                    # reference elements
                    elements.push(sample_eye.xel)
                    # reference lines
                    elements.push(sample_eye.lxel)

        $(elements).toggleClass(klass, onoff)

    toggle_class_on_row_of: (index, klass, onoff) ->
        [from, to] = @find_row(index)
        @toggle_class_on_range(from, to, klass, onoff)

    highlight_row_of: (index) ->
        $('#reading').addClass('faint')
        @toggle_class_on_row_of(index, 'highlight', true)

    highlight_range: (from, to) ->
        $('#reading').addClass('faint')
        @toggle_class_on_range(from, to, 'highlight', true)

    unhighlight: ->
        # changed because it breaks down:
        # Chrome/Mac Version 30.0.1599.101
        # (after several quick iterations, starts leaving some elements
        # untouched, and the jQuery selector returns `undefined`s in the
        # array
        # However, works in Firefox/Mac 23.0.1
        # $('.highlight').removeClass('highlight')
        $(document.querySelectorAll('.highlight')).removeClass('highlight')
        if @selection.valid()
            $('#reading').addClass('faint')
            @highlight_range(@selection.get_start(), @selection.get_end())
        else
            $('#reading').removeClass('faint')

    toggle_eyes: (eye, drawn) ->
        $("#reading").toggleClass('drawn-' + eye, drawn)

    save: (file, from, to) ->
        return if to < from
        changes = []
        for index in [from .. to]
            sample = @samples[index]
            changes.push({
                index: index
                lx: sample.left.x
                ly: sample.left.y
                rx: sample.right.x
                ry: sample.right.y
            })

        payload =
            file: file
            changes: JSON.stringify(changes)

        $.ajax
            url: 'change'
            type: 'post'
            data: payload


class EditAction

class MoveAction extends EditAction
    constructor: (@data, @from, @to, @index) ->
        @records = []
        for index in [@from .. @to]
            sample = @data.reading.samples[index]
            @records.push([
                sample.left.x
                sample.left.y
                sample.center.x
                sample.center.y
                sample.right.x
                sample.right.y
                sample.frozen
            ])

    restore: ->
        for index in [@from .. @to]
            sample = @data.reading.samples[index]
            [
                sample.left.x
                sample.left.y
                sample.center.x
                sample.center.y
                sample.right.x
                sample.right.y
                sample.frozen
            ] = @records.shift()
            last_sample = @data.reading.samples[index - 1]
            for eye in ['left', 'center', 'right']
                if sample[eye]?.el
                    sample[eye].el.setAttribute('cx', sample[eye].x)
                    sample[eye].el.setAttribute('cy', sample[eye].y)
                    $(sample[eye].el).toggleClass('frozen', sample.frozen)
                if sample[eye].sel
                    sample[eye].sel.setAttribute('x1', sample[eye].x)
                    sample[eye].sel.setAttribute('y1', sample[eye].y)
                if last_sample and last_sample[eye]?.sel
                    last_sample[eye].sel.setAttribute('x2', sample[eye].x)
                    last_sample[eye].sel.setAttribute('y2', sample[eye].y)
            if sample.iel
                sample.iel.setAttribute('x1', sample.left.x)
                sample.iel.setAttribute('y1', sample.left.y)
                sample.iel.setAttribute('x2', sample.right.x)
                sample.iel.setAttribute('y2', sample.right.y)
        [@from, @to]

class ScaleAction extends MoveAction


class UndoStack
    constructor: () ->
        @stack = []

    push: (action) ->
        @stack.push(action)

    pop: ->
        @stack.pop().restore()

    peek: ->
        @stack[@stack.length - 1]

    empty: ->
        !@stack.length


class window.FixFix
    constructor: (svg) ->
        @$svg = $(svg)
        @data = {}
        $(@$svg).svg(onLoad: @init)
        @undo = new UndoStack()
        @display_start_end = [0, null]
        @mode = null


    init: (@svg) =>
        @root = @svg.group()
        @defs = @svg.defs()
        mh = mw = 5
        arrow = @svg.marker(@defs, 'arrow', mw, mh / 2, mw, mh, 'auto', {
            markerUnits: 'userSpaceOnUse'
            color: 'black'
        })
        @svg.polyline(arrow, [[0, 0], [[mw, mh / 2], [0, mh], [mw / 12, mh / 2]]])
        @svg.style(@defs, "#reading line.drawn.saccade.highlight { marker-end: url(#arrow) }")
        @bb_group = @svg.group(@root, 'bb')
        @reading_group = @svg.group(@root, 'reading')
        @single_mode = false

        svg = @svg._svg

        $(svg).mousewheel (evt, delta, dx, dy) =>
            # zoom svg
            ctm = @root.getCTM()
            z = Math.pow(5, dy / 180)
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
                        @data.reading.highlight_row_of(index)

                        if @single_mode
                            from = to = index
                        else
                            [from, to] = [row_from, row_to] = @data.reading.find_row(index)
                            for from in [index .. row_from]
                                break if from == row_from or (from != index and @data.reading.samples[from].frozen)
                            for to in [index .. row_to]
                                break if to == row_to or (to != index and @data.reading.samples[to].frozen)
                        action = new MoveAction(@data, from, to, index)
                        @undo.push(action)

                    else if node_name == 'svg'
                    else
                        return

                    @mousedown =
                        unctm: unctm
                        origin: event_point(svg, evt).matrixTransform(unctm)
                        index: index
                        target: index && evt.target
                        eye: index? && $target.data('eye')
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
                    sample = @data.reading.samples[@mousedown.index]
                    point_delta =
                        x: point.x - sample[eye].x
                        y: point.y - sample[eye].y
                    extent = from - @mousedown.index
                    a_x = -point_delta.x / (extent * extent)
                    a_y = -point_delta.y / (extent * extent)
                    prev_sample = @data.reading.samples[from - 1]
                    for index in [from .. to]
                        sample = @data.reading.samples[index]
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
                            move_point(sample?.center?.lxel, 'x1', 'y1', sample.center)
                            move_point(prev_sample?.center?.sel, 'x2', 'y2', sample.center)
                        if sample.left and eye != 'right'
                            move_point(sample.left?.el, 'cx', 'cy', sample.left)
                            move_point(sample?.iel, 'x1', 'y1', sample.left)
                            move_point(sample.left?.sel, 'x1', 'y1', sample.left)
                            move_point(sample?.left.lxel, 'x1', 'y1', sample.left)
                            move_point(prev_sample?.left.sel, 'x2', 'y2', sample.left)
                        if sample.right and eye != 'left'
                            move_point(sample.right?.el, 'cx', 'cy', sample.right)
                            move_point(sample?.iel, 'x2', 'y2', sample.right)
                            move_point(sample.right?.sel, 'x1', 'y1', sample.right)
                            move_point(sample?.right?.lxel, 'x1', 'y1', sample.right)
                            move_point(prev_sample?.right?.sel, 'x2', 'y2', sample.right)

                        prev_sample = sample
                    sample = @data.reading.samples[@mousedown.index]
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

        stop_drag = =>
            if @data?.reading?
                @data.reading.unhighlight()

            @mousedrag = false
            @mousedown = false


        $(svg).mouseup((evt) =>
            if @mousedrag
                @$svg.removeClass('dragging')

                if @mousedown.index?
                    # it was a move
                    sample = @data.reading.samples[@mousedown.index]
                    sample.fix()
                    @$svg.trigger('dirty')
                    @data.reading.save(@reading_file, @mousedown.row...)

            stop_drag()
        )

        $(document).keyup (evt) =>
            if @mousedrag and evt.which == 27 # Esc
                @undo.pop()
                stop_drag()

    scale_selection: (moved_index, scale_index, affect_x, affect_y) ->
        selection_start = @data.reading.selection.get_start()
        selection_end = @data.reading.selection.get_end()
        last_undo = @undo.peek()

        moved_sample = @data.reading.samples[last_undo.index]
        move_info = last_undo.records[last_undo.index - last_undo.from]

        delta_left_x = move_info[0] - moved_sample.left.x
        delta_left_y = move_info[1] - moved_sample.left.y
        delta_center_x = move_info[2] - moved_sample.center.x
        delta_center_y = move_info[3] - moved_sample.center.y
        delta_right_x = move_info[4] - moved_sample.right.x
        delta_right_y = move_info[5] - moved_sample.right.y

        @undo.pop()
        @undo.push(new ScaleAction(@data, selection_start, selection_end, moved_index))
        scale_sample = if scale_index? then @data.reading.samples[scale_index] else null

        scale_delta = (orig_value, moved_orig_value, scale_point_orig_value, delta_at_moved_point) ->
            scale_factor =
                if scale_point_orig_value
                    (orig_value - scale_point_orig_value) / (moved_orig_value - scale_point_orig_value)
                else
                    1
            delta_at_moved_point * scale_factor

        for index in [selection_start .. selection_end]
            sample = @data.reading.samples[index]
            if affect_x
                sample.left.x -= scale_delta(sample.left.x, moved_sample.left.x, scale_sample and scale_sample.left.x, delta_left_x)
                sample.center.x -= scale_delta(sample.center.x, moved_sample.center.x, scale_sample and scale_sample.center.x, delta_center_x)
                sample.right.x -= scale_delta(sample.right.x, moved_sample.right.x, scale_sample and scale_sample.right.x, delta_right_x)
            if affect_y
                sample.left.y -= scale_delta(sample.left.y, moved_sample.left.y, scale_sample and scale_sample.left.y, delta_left_y)
                sample.center.y -= scale_delta(sample.center.y, moved_sample.center.y, scale_sample and scale_sample.center.y, delta_center_y)
                sample.right.y -= scale_delta(sample.right.y, moved_sample.right.y, scale_sample and scale_sample.right.y, delta_right_y)

        last_sample = @data.reading.samples[selection_start - 1]
        for index in [selection_start .. selection_end]
            sample = @data.reading.samples[index]
            for eye in ['left', 'center', 'right']
                if sample[eye]?.el
                    sample[eye].el.setAttribute('cx', sample[eye].x)
                    sample[eye].el.setAttribute('cy', sample[eye].y)
                if sample[eye].sel
                    sample[eye].sel.setAttribute('x1', sample[eye].x)
                    sample[eye].sel.setAttribute('y1', sample[eye].y)
                if last_sample and last_sample[eye]?.sel
                    last_sample[eye].sel.setAttribute('x2', sample[eye].x)
                    last_sample[eye].sel.setAttribute('y2', sample[eye].y)
            if sample.iel
                sample.iel.setAttribute('x1', sample.left.x)
                sample.iel.setAttribute('y1', sample.left.y)
                sample.iel.setAttribute('x2', sample.right.x)
                sample.iel.setAttribute('y2', sample.right.y)
            last_sample = sample

        @$svg.trigger('dirty')
        @data.reading.save(@reading_file, selection_start, selection_end)
        @scale_point = moved_index

    sample_reviver: (k, v) ->
        if v? and typeof(v) == 'object'
            if "word" of v
                return new Word(v.word, v.left, v.top, v.right, v.bottom)
            else if "validity" of v
                return new Gaze(v.x, v.y, v.pupil, v.validity)
            else if "time" of v
                return new Sample(v.time, v.rs, v.blink, v.left, v.right, v.duration, v.start, v.end)
            else if "samples" of v
                return new Reading(v.samples, v.flags, v.row_bounds || [])
        return v

    load: (file) ->
        @opts.load = file
        ($.ajax
            url: "load.json"
            dataType: 'json'
            data: @opts
            revivers: @sample_reviver
        ).then (data) =>
            for type of data?.payload || []
                @data[type] = data.payload[type]
                @data[type].opts = this.opts
                switch type
                    when 'bb' then @render_bb()
                    when 'reading'
                        @reading_file = file
                        delete @reference_file
                        if @data.reading.flags.center
                            for sample in @data.reading.samples
                                sample.build_center()
                        for sample, index in @data.reading.samples
                            sample.index = index
                        @data.reading.unhighlight()
                        display_end = Math.min(display_samples, @data.reading.samples.length)
                        @display_start_end = [0, display_end]
                        @render_reading()
                        @undo = new UndoStack()
                        @$svg.trigger('loaded')

    load_reference: (file) ->
        @opts.load = file
        ($.ajax
            url: "load.json"
            dataType: 'json'
            data: @opts
            revivers: @sample_reviver
        ).then (data) =>
            @reference_file = file
            ref_samples = data.payload.reading.samples
            samples = @data.reading.samples
            i = 0
            len = samples.length
            for sample in ref_samples
                i += 1 while i < len and samples[i].time < sample.time
                break if i >= len
                if samples[i].time == sample.time && samples[i].duration == sample.duration
                    sample.build_center() if @data.reading.flags.center
                    samples[i].reference =
                        left: sample.left
                        right: sample.right
                        center: sample.center
            @render_reading()

    render_bb: ->
        $(@bb_group).empty()
        word_group = @svg.group(@bb_group, 'text')
        for word in @data.bb
            word.render_box(@svg, word_group)

        text_group = @svg.group(@bb_group, 'text')
        for word in @data.bb
            word.render_word(@svg, text_group)

    render_reading: ->
        $(@reading_group).empty()
        tree_factor = 20

        samples = @data.reading.samples
        # TODO remove flags.center
        [start, end] = this.display_start_end
        end = samples.length unless end?
        if @data.reading.flags.lines
            treedraw @svg, @svg.group(@reading_group), start, end, tree_factor, (parent, index) =>
                sample = samples[index]
                if sample?
                    sample.render_intereye(@svg, parent)
        for eye in ['left', 'right', 'center']
            if @data.reading.flags.lines
                treedraw @svg, @svg.group(@reading_group), start, end - 1, tree_factor, (parent, index) =>
                    sample1 = samples[index]
                    sample2 = samples[index + 1]
                    if sample1? and sample2?
                        sample1.render_saccade(@svg, parent, eye, sample2)
            treedraw @svg, @svg.group(@reading_group), start, end, tree_factor, (parent, index) =>
                sample = samples[index]
                if sample?
                    sample.render(@svg, parent, eye)
            if @reference_file
                treedraw @svg, @svg.group(@reading_group), start, end, tree_factor, (parent, index) =>
                    sample = samples[index]
                    if sample?
                        sample.render_reference(@svg, parent, eye)
                treedraw @svg, @svg.group(@reading_group), start, end, tree_factor, (parent, index) =>
                    sample = samples[index]
                    if sample?
                        sample.render_reference_line(@svg, parent, eye)
        @$svg.trigger('rendered')

    perform_undo: ->
        [from, to] = @undo.pop()
        @$svg.trigger('dirty')
        @data.reading.save(@reading_file, from, to)



class window.FixFixUI
    constructor: (fixfix, browser) ->
        fixations = null
        load_timer = null
        nocache = false
        selection_jump = 500 # default: half a second

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

            if nocache
                opts.nocache = true
                nocache = false
            else
                delete opts.nocache

            fixfix.opts = opts

        $(browser).fileTree {
                script: 'files'
                multiFolder: false,
            },
            (file, $selected) =>
                delete fixfix.opts.nocache
                fixfix.load(file)

        load = =>
            if fixfix.reading_file
                nocache = true
                set_opts()
                fixfix.load(fixfix.reading_file)

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

        set_slider = (element, start, end) ->
            samples = fixfix.data.reading.samples
            start_time = samples[start]?.time
            end_time = samples[end]?.time
            $(element).val([start_time, end_time])
        reinit_sliders = ->
            [start, end] = fixfix.display_start_end
            samples = fixfix.data.reading.samples
            [start_time, display_start_time, display_end_time, end_time] =
                [0, start, end - 1, samples.length - 1].map((index) -> samples[index].time)
            max_num_pips = Math.floor(document.body.clientWidth / 100)
            range = end_time - start_time
            # This can probably be simpler...
            pip = Math.pow(10, Math.ceil(Math.log(range / max_num_pips) / Math.log(10)))
            start_pip = Math.round(Math.ceil(start_time / pip)) * pip
            end_pip = Math.round(Math.floor(end_time / pip)) * pip
            num_pips = (end_pip - start_pip) / pip
            minors = [10, 5, 4, 2, 1]
            for minor in minors
                break if num_pips * minor <= max_num_pips
            minor_pip = pip / minor
            start_pip = Math.round(Math.ceil(start_time / minor_pip)) * minor_pip
            end_pip = Math.round(Math.floor(end_time / minor_pip)) * minor_pip

            $('#display-slider').noUiSlider
                start: [display_start_time, display_end_time]
                range:
                    min: start_time
                    max: end_time,
                true
            .noUiSlider_pips
                mode: 'values'
                values: (x for x in [start_pip..end_pip] by minor_pip)
                filter: (value, type) =>
                    if value % pip == 0 then 1 else 2
            $('#selection-slider').noUiSlider
                start: [start_time, end_time]
                range:
                    min: start_time
                    max: end_time,
                true

        $('#display-slider').noUiSlider
            start: [0, 1]
            range:
                min: 0
                max: 1
            connect: true
            margin: 1
            behaviour: 'drag'
        .on
            change: (evt) =>
                [start, end] = $(evt.target).val()
                start = fixfix.data.reading.selection.binary_search_sample(start)
                end = fixfix.data.reading.selection.binary_search_sample(end)
                fixfix.display_start_end = [start, end]
                fixfix.render_reading()
        $('#selection-slider').noUiSlider
            start: [0, 1]
            range:
                min: 0
                max: 1
            connect: true
            margin: 1
            behaviour: 'drag'
        .on
            change: (evt) =>
                start_end = $(evt.target).val()
                fixfix.data.reading.selection.set_start_end_time(start_end[0], start_end[1])
                fixfix.data.reading.unhighlight()

        $('#i-dt').click(load)

        # TODO don't redraw things that are already drawn
        $('#eye-options input').click (evt) =>
            if fixfix.reading_file
                $target = $(evt.target)
                eye = evt.target.id.substr(0, evt.target.id.indexOf('-'))
                fixfix.data.reading.toggle_eyes(eye, $target.is(':checked'))

        fixfix.$svg.on 'click', (evt) =>
            document.activeElement.blur()

        fixfix.$svg.on 'loaded', (evt) =>
            fixation_opts = fixfix.data.reading.flags.fixation
            fixation_opts_active = fixation_opts instanceof Object
            $('#i-dt').prop('checked', !!fixation_opts)
            if fixation_opts_active
                for key, value of fixation_opts
                    $("##{key}, ##{key}-n").val(value)
            $('#scrap-options').toggleClass('hide-fix', !!fixation_opts && !fixation_opts_active)
            $('#smoothing, #smoothing-n').val(fixfix.data.reading.flags.smoothing)
            $('#fix-options').toggleClass('dirty', !!fixfix.data.reading.flags.dirty)
            reading_file_name = fixfix.reading_file.replace(/^.*\/([^/]*)\.[^/.]+$/, '$1')
            $('#fixfix-link').attr
                href: "dl/fixfix#{fixfix.reading_file}"
                download: "#{reading_file_name}.fixfix"
            if fixfix.data.reading.flags.xml
                $('#xml-link').css('display', 'inline').attr
                    href: "dl/xml#{fixfix.reading_file}"
                    download: "#{reading_file_name}.xml"
            else
                $('#xml-link').css('display', 'none')
            $('#download').css('display', 'block')

            samples = fixfix.data.reading.samples
            reinit_sliders()

        fixfix.$svg.on 'dirty', (evt) ->
            $('#fix-options').addClass('dirty')
        $('#scrap-changes-btn').click (evt) =>
            load()
            fixfix.$svg.trigger('clean')

        fixfix.$svg.on 'rendered', (evt) =>
            for eye in ['left', 'center', 'right', 'ref']
                fixfix.data.reading.toggle_eyes(eye, $("##{eye}-eye").is(':checked'))


        # upload handler
        jQuery_xhr_factory = $.ajaxSettings.xhr
        exts = ['xml', 'fixfix', 'tsv', 'bb']
        upload = (files, $ul, dir) ->
            for file in files
                # find extension
                [_, ext] = file.name.match /\.([^./]+)$/
                continue if exts.indexOf(ext) == -1

                # insert into file browser
                $a = $ul.find('a[rel$="/' + file.name + '"]')
                if $a.length
                    # exists
                    $li = $a.parent()
                else
                    $a = $('<a href="#"/>').text(file.name).attr('rel', dir + file.name)
                    $li = $('<li class="file"/>').addClass('ext_' + ext).append($a)
                    $ul.append($li)

                # perform upload
                form = new FormData()
                form.append(dir + file.name, file)
                (($li) ->
                    $.ajax
                        url: 'upload'
                        data: form
                        type: "POST"
                        contentType: false
                        processData: false
                        xhr: ->
                            req = jQuery_xhr_factory()
                            req.upload.addEventListener "progress", this.progressUpload, false
                            req
                        progressUpload: (evt) ->
                            progress = Math.round(100 * evt.loaded / evt.total)
                            $li.css('background', "linear-gradient(to right, rgba(255,255,255,0.30) 0%,rgba(0,0,255,0.30) #{progress}%,rgba(0,0,0,0) #{progress}%,rgba(0,0,0,0) 100%)")
                        success: ->
                            $li.css('background', '')
                        error: ->
                            $li.remove()
                )($li)

                
        # upload by dragging files in
        $('#browser').on 'dragover', (evt) ->
            evt.preventDefault()
        $('#browser').on 'dragenter', (evt) ->
            evt.preventDefault()
        $('#browser').on 'drop', (evt) ->
            if evt.originalEvent.dataTransfer?.files?.length
                # find out the directory
                is_root = evt.target.id == 'browser'
                $target = $(evt.target)
                unless is_root
                    if $target[0].tagName isnt 'A'
                        $target = $target.children('a')
                    $target_li = $target.parent()
                path = if is_root then '/' else $target.attr('rel')
                [_, target_directory, target_file] = path.match /^(.*\/)([^/]*)$/

                window.$t = $target
                if is_root
                    $ul = $target.children('ul')
                else if target_file
                    $ul = $target.closest('ul')
                else if $target_li.hasClass('expanded')
                    $ul = $target.next()
                
                if $ul
                    upload(evt.originalEvent.dataTransfer.files, $ul, target_directory)
                else
                    # open the directory
                    files = evt.originalEvent.dataTransfer.files
                    $target_li.one 'show', (evt, $li) ->
                        $ul = $li.children('ul')
                        upload(files, $ul, target_directory)
                    $target.click()
                stop(evt)


        # file browser context menu
        make_new_folder_input = ($ul, path) ->
            $input = $('<input/>')
            $li = $('<li class="directory collapsed"/>').append($input)
            $ul.append($li)
            $input.focus()
            $input
                .on 'blur change', (evt) ->
                    unless (name = $input.val())
                        $input.closest('li').remove()
                        return
                    new_path = path + name + '/'
                    $.ajax
                        url: 'mkdir' + new_path
                        type: 'POST'
                        success: ->
                            $input.remove()
                            $a = $('<a href="#"/>').text(name).attr('rel', new_path)
                            $li.append($a)
                            $li.click()
                        error: ->
                            $input.closest('li').remove()
        $('#browser').contextMenu
            selector: 'li'
            animation:
                duration: 0
            build: ($trigger, evt) ->
                path = $trigger.find('a').attr('rel')
                type = if path[path.length - 1] == '/' then 'directory' else 'file'
                ext = path.match(/[^.\/]*$/)[0]
                items:
                    delete:
                        name: "Delete"
                        callback: (key, options) ->
                            if confirm("Are you sure you wish to delete the #{type} #{path}?")
                                $.ajax
                                    url: 'delete' + path
                                    type: "POST"
                                    success: ->
                                        $trigger.remove()
                    reference:
                        name: "Load Reference"
                        disabled: type != 'file' || ["fixfix", "tsv", "xml"].indexOf(ext) == -1 || fixfix.reading_file == path
                        callback: (key, options) ->
                            fixfix.load_reference(path)
                    folder:
                        name: "New Folder"
                        callback: (key, options) ->
                            [_, target_directory, target_file] = path.match /^(.*\/)([^/]*)$/
                            if target_file
                                $ul = $trigger.closest('ul')
                            else if $trigger.hasClass('expanded')
                                $ul = $trigger.find('ul')

                            if $ul
                                make_new_folder_input($ul, target_directory)
                            else
                                $trigger.one 'show', (evt, $li) ->
                                    $ul = $li.children('ul')
                                    make_new_folder_input($ul, target_directory)
                                $trigger.find('a').click()
        $.contextMenu
            selector: '#browser'
            animation:
                duration: 0
            build: ($trigger, evt) ->
                file = $trigger.find('a').attr('rel')
                items:
                    folder:
                        name: "New Folder"
                        callback: (key, options) ->
                            $ul = $trigger.children('ul')
                            make_new_folder_input($ul, '/')


        # circle context menu
        $(fixfix.svg._svg).contextMenu
            selector: 'circle'
            animation:
                duration: 0
            build: ($trigger, evt) ->
                index = $trigger.data('index')
                eye = $trigger.data('eye')
                sample = fixfix.data.reading.samples[index]
                [from, to] = fixfix.data.reading.find_row(index)

                items:
                    header:
                        name: "##{index} #{eye} (#{sample.time} ms)"
                        className: "header"
                        disabled: true
                    frozen: make_checkbox
                        name: "Frozen"
                        disabled: index <= from or index >= to
                        selected: sample.frozen
                        click: (evt) ->
                            sample.fix(!sample.frozen)
                            click
                    unfreeze_row:
                        name: "Unfreeze Row"
                        callback: (key, options) ->
                            for index in [from + 1 ... to]
                                fixfix.data.reading.samples[index].fix(false)
                    separator1: "----------"
                    select_start:
                        name: "Selection Start"
                        callback: (key, options) ->
                            fixfix.data.reading.selection.set_start(index)
                            set_slider('#selection-slider', fixfix.data.reading.selection.start, fixfix.data.reading.selection.end)
                            fixfix.data.reading.unhighlight()
                    select_end:
                        name: "Selection End"
                        callback: (key, options) ->
                            fixfix.data.reading.selection.set_end(index)
                            set_slider('#selection-slider', fixfix.data.reading.selection.start, fixfix.data.reading.selection.end)
                            fixfix.data.reading.unhighlight()
                    scale_point:
                        name: "Scale Point"
                        callback: (key, options) ->
                            fixfix.scale_point = index

        # blank space context menu
        $.contextMenu
            selector: 'svg'
            animation:
                duration: 0
            build: ($trigger, evt) ->
                last_undo = fixfix.undo.peek()
                move_present = last_undo and (last_undo.constructor is MoveAction)
                items:
                    single: make_checkbox
                        name: "Single mode"
                        selected: fixfix.single_mode
                        click: (evt) ->
                            fixfix.single_mode = !fixfix.single_mode
                            true
                    undo:
                        name: "Undo"
                        disabled: fixfix.undo.empty()
                        callback: (key, options) ->
                            fixfix.perform_undo()
                    mode_sep: "----------"
                    move:
                        name: "Move"
                        disabled: !move_present
                        callback: (key, options) ->
                            fixfix.scale_selection(last_undo.index, null, true, true)
                    scale:
                        name: "Scale"
                        disabled: !(fixfix.scale_point? and move_present and fixfix.scale_point != last_undo.index)
                        callback: (key, options) ->
                            fixfix.scale_selection(last_undo.index, fixfix.scale_point, true, true)
                    select_clear:
                        name: "Selection Clear"
                        disabled: !fixfix?.data?.reading?.selection?.valid()
                        callback: (key, options) ->
                            fixfix.data.reading.selection.clear()
                            fixfix.data.reading.unhighlight()
                    select_speed:
                        name: "Jump Speed"
                        items:
                            selspeed_100ms: make_checkbox
                                name: "100 ms"
                                selected: selection_jump == 100
                                click: (evt) ->
                                    selection_jump = 100
                            selspeed_200ms: make_checkbox
                                name: "200 ms"
                                selected: selection_jump == 200
                                click: (evt) ->
                                    selection_jump = 200
                            selspeed_500ms: make_checkbox
                                name: "500 ms"
                                selected: selection_jump == 500
                                click: (evt) ->
                                    selection_jump = 500
                            selspeed_1000ms: make_checkbox
                                name: "1000 ms"
                                selected: selection_jump == 1000
                                click: (evt) ->
                                    selection_jump = 1000
                            selspeed_sep: "---"
                            selspeed_100000ms: make_checkbox
                                name: "100000 ms"
                                selected: selection_jump == 100000
                                click: (evt) ->
                                    selection_jump = 100000
                            selspeed_200000ms: make_checkbox
                                name: "200000 ms"
                                selected: selection_jump == 200000
                                click: (evt) ->
                                    selection_jump = 200000
                            selspeed_500000ms: make_checkbox
                                name: "500000 ms"
                                selected: selection_jump == 500000
                                click: (evt) ->
                                    selection_jump = 500000
                            selspeed_1000000ms: make_checkbox
                                name: "1000000 ms"
                                selected: selection_jump == 1000000
                                click: (evt) ->
                                    selection_jump = 1000000

        $(document).keydown (evt) ->
            return unless fixfix.reading_file?
            $target = $(evt.target)
            # ignore input elements with text
            return true if $target.is('input:text, input:password')
            switch evt.keyCode
                when 37 # left
                    fixfix.data.reading.selection.next(-1, selection_jump)
                    set_slider('#selection-slider', fixfix.data.reading.selection.start, fixfix.data.reading.selection.end)
                    stop(evt)
                when 39 # right
                    fixfix.data.reading.selection.next(+1, selection_jump)
                    set_slider('#selection-slider', fixfix.data.reading.selection.start, fixfix.data.reading.selection.end)
                    stop(evt)
                when 90 # Z
                    unless fixfix.undo.empty()
                        fixfix.perform_undo()
                        addFadeHint("Undo")
                    stop(evt)
                when 32 # space
                    fixfix.single_mode = !fixfix.single_mode
                    addFadeHint("Single Mode " + (if fixfix.single_mode then 'ON' else 'OFF'))
                    stop(evt)


        stop = (evt) ->
            evt.preventDefault()
            evt.stopPropagation()
            false

        make_checkbox = (args) ->
            args['type'] = 'checkbox'
            args['events'] ||= {}
            click_handler = args['click']
            delete args['click']
            args['events']['click'] = (evt) ->
                $(this).closest('.context-menu-root').contextMenu('hide')
                click_handler()
            args


        set_opts()

        addSlideHint = (html) ->
            $('#help').
                html(html).
                slideDown(800).
                delay(4000).
                slideUp(800)

        addFadeHint = (html) ->
            $('#help').
                stop(true, true).
                show().
                html(html).
                delay(1000).
                fadeOut(400)

        addSlideHint("To upload, drag and drop your files into FixFix file browser")
