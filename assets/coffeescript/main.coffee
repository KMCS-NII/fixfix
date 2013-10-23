# vim: ts=4:sts=4:sw=4


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
    constructor: (@time, @rs, @blink, @left, @right, @duration, @start, @end) ->

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
            klass = 'saccade drawn ' + eye
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
            @selection =
                start: null
                end: null

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
        $('#gaze').addClass('faint')
        @toggle_class_on_row_of(index, 'highlight', true)

    highlight_range: (from, to) ->
        $('#gaze').addClass('faint')
        @toggle_class_on_range(from, to, 'highlight', true)

    get_selection: (force) ->
        if @selection.start or @selection.end or force
            return {
                start: @selection.start || 0
                end: to = @selection.end || (@samples.length - 1)
            }
        else
            return null

    unhighlight: ->
        $('.highlight').removeClass('highlight')
        if (selection = @get_selection())
            $('#gaze').addClass('faint')
            @highlight_range(selection.start, selection.end)
        else
            $('#gaze').removeClass('faint')

    save: (from, to) ->
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
            file: @opts.file
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
            sample = @data.gaze.samples[index]
            @records.push([
                sample.left.x
                sample.left.y
                sample.center.x
                sample.center.y
                sample.right.x
                sample.right.y
            ])

    restore: ->
        for index in [@from .. @to]
            sample = @data.gaze.samples[index]
            [
                sample.left.x
                sample.left.y
                sample.center.x
                sample.center.y
                sample.right.x
                sample.right.y
            ] = @records.shift()
            last_sample = @data.gaze.samples[index - 1]
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
        @svg.style(@defs, "#gaze line.drawn.saccade.highlight { marker-end: url(#arrow) }")
        @bb_group = @svg.group(@root, 'bb')
        @gaze_group = @svg.group(@root, 'gaze')
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
                        @data.gaze.highlight_row_of(index)

                        if @single_mode
                            from = to = index
                        else
                            [from, to] = [row_from, row_to] = @data.gaze.find_row(index)
                            for from in [index .. row_from]
                                break if from == row_from or (from != index and @data.gaze.samples[from].frozen)
                            for to in [index .. row_to]
                                break if to == row_to or (to != index and @data.gaze.samples[to].frozen)
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
                    sample = @data.gaze.samples[@mousedown.index]
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
            if @data?.gaze?
                @data.gaze.unhighlight()

            @mousedrag = false
            @mousedown = false


        $(svg).mouseup((evt) =>
            if @mousedrag
                @$svg.removeClass('dragging')

                if @mousedown.index?
                    # it was a move
                    sample = @data.gaze.samples[@mousedown.index]
                    sample.fix()
                    @$svg.trigger('dirty')
                    @data.gaze.save(@mousedown.row...)

            stop_drag()
        )

        $(document).keyup (evt) =>
            if @mousedrag and evt.which == 27 # Esc
                @undo.pop()
                stop_drag()

    scale_selection: (moved_index, scale_index, affect_x, affect_y) ->
        selection = @data.gaze.get_selection(true)
        last_undo = @undo.peek()

        moved_sample = @data.gaze.samples[last_undo.index]
        move_info = last_undo.records[last_undo.index - last_undo.from]

        delta_left_x = move_info[0] - moved_sample.left.x
        delta_left_y = move_info[1] - moved_sample.left.y
        delta_center_x = move_info[2] - moved_sample.center.x
        delta_center_y = move_info[3] - moved_sample.center.y
        delta_right_x = move_info[4] - moved_sample.right.x
        delta_right_y = move_info[5] - moved_sample.right.y

        @undo.pop()
        @undo.push(new ScaleAction(@data, selection.start, selection.end, moved_index))
        scale_sample = if scale_index? then @data.gaze.samples[scale_index] else null

        scale_delta = (orig_value, moved_orig_value, scale_point_orig_value, delta_at_moved_point) ->
            scale_factor =
                if scale_point_orig_value
                    (orig_value - scale_point_orig_value) / (moved_orig_value - scale_point_orig_value)
                else
                    1
            delta_at_moved_point * scale_factor

        for index in [selection.start .. selection.end]
            sample = @data.gaze.samples[index]
            if affect_x
                sample.left.x -= scale_delta(sample.left.x, moved_sample.left.x, scale_sample and scale_sample.left.x, delta_left_x)
                sample.center.x -= scale_delta(sample.center.x, moved_sample.center.x, scale_sample and scale_sample.center.x, delta_center_x)
                sample.right.x -= scale_delta(sample.right.x, moved_sample.right.x, scale_sample and scale_sample.right.x, delta_right_x)
            if affect_y
                sample.left.y -= scale_delta(sample.left.y, moved_sample.left.y, scale_sample and scale_sample.left.y, delta_left_y)
                sample.center.y -= scale_delta(sample.center.y, moved_sample.center.y, scale_sample and scale_sample.center.y, delta_center_y)
                sample.right.y -= scale_delta(sample.right.y, moved_sample.right.y, scale_sample and scale_sample.right.y, delta_right_y)

        last_sample = @data.gaze.samples[selection.start - 1]
        for index in [selection.start .. selection.end]
            sample = @data.gaze.samples[index]
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
        @data.gaze.save(selection.start, selection.end)
        @scale_point = moved_index

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
                        return new Sample(v.time, v.rs, v.blink, v.left, v.right, v.duration, v.start, v.end)
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
                    @undo = new UndoStack()
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


        $(fixfix.svg._svg).contextMenu({
            selector: 'circle',
            animation:
                duration: 0
            build: ($trigger, evt) ->
                index = $trigger.data('index')
                eye = $trigger.data('eye')
                sample = fixfix.data.gaze.samples[index]
                [from, to] = fixfix.data.gaze.find_row(index)

                items =
                    header:
                        name: "##{index} #{eye} (#{sample.time} ms)"
                        className: "header"
                        disabled: true
                    frozen:
                        name: "Frozen"
                        disabled: index <= from or index >= to
                        icon: if sample.frozen then "checkmark" else undefined
                        callback: (key, options) ->
                            sample.fix(!sample.frozen)
                    unfreeze_row:
                        name: "Unfreeze Row"
                        callback: (key, options) ->
                            for index in [from + 1 ... to]
                                fixfix.data.gaze.samples[index].fix(false)
                    separator1: "----------"
                    select_start:
                        name: "Selection Start"
                        callback: (key, options) ->
                            fixfix.data.gaze.selection.start = index
                            fixfix.data.gaze.unhighlight()
                    select_end:
                        name: "Selection End"
                        callback: (key, options) ->
                            fixfix.data.gaze.selection.end = index
                            fixfix.data.gaze.unhighlight()
                    scale_point:
                        name: "Scale Point"
                        callback: (key, options) ->
                            fixfix.scale_point = index

                return {
                    items: items
                }
        })


        $.contextMenu({
            selector: 'body'
            animation:
                duration: 0
            build: ($trigger, evt) ->
                last_undo = fixfix.undo.peek()
                move_present = last_undo and (last_undo.constructor is MoveAction)
                items =
                    single:
                        name: "Single mode"
                        icon: if fixfix.single_mode then "checkmark" else undefined
                        callback: (key, options) ->
                            fixfix.single_mode = !fixfix.single_mode
                            true
                    undo:
                        name: "Undo"
                        disabled: fixfix.undo.empty()
                        callback: (key, options) ->
                            [from, to] = fixfix.undo.pop()
                            fixfix.$svg.trigger('dirty')
                            fixfix.data.gaze.save(from, to)
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
                        disabled: !fixfix?.data?.gaze?.get_selection()
                        callback: (key, options) ->
                            fixfix.data.gaze.selection =
                                start: null
                                end: null
                            fixfix.data.gaze.unhighlight()


                return {
                    items: items
                }
        })


        set_opts()
