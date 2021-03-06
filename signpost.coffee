# signpost.c: implementation of the janko game 'arrow path'
Math.seedrandom?('foo')

class GameParams
	constructor: (@w, @h, @force_corner_start) ->
		throw 'W, H must at least be 2' if @w < 2 or @h < 2
		throw 'One must at least be 3' if @w == 2 and @h == 2

	new_game: ->
		for x in [0 .. 50]
			state = new game_state(@w, @h)
			# keep trying until we fill successfully.
			while true
				if @force_corner_start
					headi = 0
					taili = state.n - 1
				else
					while true
						headi = Math.random_int(state.n)
						taili = Math.random_int(state.n)
						break unless headi == taili
				break if state.new_game_fill(headi, taili)
			state.cells[headi].immutable = true
			state.cells[taili].immutable = true
			# This will have filled in directions and _all_ numbers.
			# Store the game definition for this, as the solved-state.
			if state.new_game_strip()
				state.strip_nums()
				state.update_numbers()
				state.check_completion(true) # update any auto-links
				return state
		throw 'Game generation failed.'


DIRECTION = [
	{x:  0, y: -1} # N
	{x:  1, y: -1} # NE
	{x:  1, y:  0} # E
	{x:  1, y:  1} # SE
	{x:  0, y:  1} # S
	{x: -1, y:  1} # SW
	{x: -1, y:  0} # W
	{x: -1, y: -1} # NW
]

DIR_OPPOSITE = (d) -> 0|((d + 4) % 8)

dir_angle = (dir) ->
	2.0 * Math.PI * dir / 8.0

whichdir = (fromx, fromy, tox, toy) ->
	dx = tox - fromx
	dy = toy - fromy
	if dx and dy and Math.abs(dx) != Math.abs(dy)
		return -1
	if dx
		dx = 0|(dx / Math.abs(dx)) # limit to (-1, 0, 1)
	if dy
		dy = 0|(dy / Math.abs(dy)) # ditto
	for dir, i in DIRECTION
		if dx == dir.x and dy == dir.y
			return i
	return -1

class Cell
	constructor: ->
		@dir = 0
		@num = 0
		@immutable = false
		@error = false
		@next = -1
		@prev = -1

	clone: ->
		c = new Cell()
		c.dir = @dir
		c.num = @num
		c.immutable = @immutable
		c.error = @error
		c.next = @next
		c.prev = @prev
		c

class game_state
	constructor: (@w, @h) ->
		@n = @w * @h
		@completed = @used_solve = @impossible = false #int
		@cells = for i in [0 .. @n - 1]
			new Cell()
		@dsf = new DisjointSetForest(@n) # connects regions with a dsf.
		@numsi = snewn(@n + 1) # for each number, which index is it in? (-1 absent)
		@numsi.fill(-1)

	clone: ->
		to = new game_state(@w, @h)
		to.completed = @completed
		to.used_solve = @used_solve
		to.impossible = @impossible
		to.cells = for c in @cells
			c.clone()
		to.dsf = @dsf.clone()
		for v, i in @numsi
			to.numsi[i] = v
		to

	in_grid: (x, y) ->
		x >= 0 and x < @w and y >= 0 and y < @h

	is_real_number: (num) ->
		num > 0 and num <= @n

	region_colour: (a) ->
		0|(a / (@n + 1))

	region_start: (c) ->
		c * (@n + 1)

	whichdiri: (fromi, toi) ->
		whichdir(0|(fromi % @w), 0|(fromi / @w), 0|(toi % @w), 0|(toi / @w))

	ispointing: (fromx, fromy, tox, toy) ->
		dir = @cells[fromy * @w + fromx].dir
		# (by convention) squares do not poto themselves.
		if fromx == tox and fromy == toy
			return false
		# the final number points to nothing.
		if @cells[fromy * @w + fromx].num == @n
			return false
		while true
			if not @in_grid(fromx, fromy)
				return false
			if fromx == tox and fromy == toy
				return true
			fromx += DIRECTION[dir].x
			fromy += DIRECTION[dir].y
		null # not reached

	ispointingi: (fromi, toi) ->
		@ispointing(0|(fromi % @w), 0|(fromi / @w), 0|(toi % @w), 0|(toi / @w))

	# Taking the number 'num', work out the gap between it and the next
	# available number up or down (depending on d). Return 1 if the region
	# at (x,y) will fit in that gap, or 0 otherwise.
	move_couldfit: (num, d, x, y) ->
		i = y * @w + x
		cell = @cells[i]
		# The 'gap' is the number of missing numbers in the grid between
		# our number and the next one in the sequence (up or down), or
		# the end of the sequence (if we happen not to have 1/n present)
		n = num + d
		gap = 0
		while @is_real_number(n) and @numsi[n] == -1
			n += d
			gap++
		if gap == 0
			# no gap, so the only allowable move is that that directly
			# links the two numbers.
			cell.num != num + d
		else if cell.prev == -1 and cell.next == -1
			true # single unconnected square, always OK
		else
			@dsf.size(i) <= gap

	isvalidmove: (clever, fromx, fromy, tox, toy) ->
		return false unless @in_grid(fromx, fromy)
		return false unless @in_grid(tox, toy)
		# can only move where we point
		return false unless @ispointing(fromx, fromy, tox, toy)
		from = fromy * @w + fromx
		to = toy * @w + tox
		nfrom = @cells[from].num
		nto = @cells[to].num
		# can't move _from_ the preset final number, or _to_ the preset 1.
		return false if nfrom == @n and @cells[from].immutable
		return false if nto == 1 and @cells[to].immutable
		# can't create a new connection between cells in the same region
		# as that would create a loop.
		return false if @dsf.canonify(from) == @dsf.canonify(to)
		# if both cells are actual numbers, can't drag if we're not
		# one digit apart.
		if @is_real_number(nfrom) and @is_real_number(nto)
			nfrom == nto - 1
		else if clever and @is_real_number(nfrom)
			@move_couldfit(nfrom, +1, tox, toy)
		else if clever and @is_real_number(nto)
			@move_couldfit(nto, -1, fromx, fromy)
		else
			true

	makelink: (from, to) ->
		c_from = @cells[from]
		c_to = @cells[to]
		if c_from.next != -1
			@cells[c_from.next].prev = -1
		c_from.next = to
		if c_to.prev != -1
			@cells[c_to.prev].next = -1
		c_to.prev = from
		null

	unlink_cell: (si) ->
		cell = @cells[si]
		if cell.prev != -1
			@cells[cell.prev].next = -1
			cell.prev = -1
		if cell.next != -1
			@cells[cell.next].prev = -1
			cell.next = -1
		null

	strip_nums: ->
		for c in @cells
			if not c.immutable
				c.num = 0
			c.next = c.prev = -1
		@numsi.fill(-1)
		@dsf.constructor(@n)
		null

	# Game generation 

	# Fills in preallocated arrays ai (indices) and ad (directions)
	# showing all non-numbered cells adjacent to index i, returns length
	# This function has been somewhat optimised...
	cell_adj: (i) ->
		adjacent = []
		sx = 0|(i % @w)
		sy = 0|(i / @w)
		for dir, a in DIRECTION
			x = sx
			y = sy
			while true
				x += dir.x
				y += dir.y
				break unless @in_grid(x, y)
				newi = y * @w + x
				if @cells[newi].num == 0
					adjacent.push [newi, a]
		adjacent

	new_game_fill: (headi, taili) ->
		for c in @cells
			c.num = 0
		@cells[headi].num = 1
		@cells[taili].num = @n
		@cells[taili].dir = 0
		nfilled = 2
		while nfilled < @n
			# Try and expand _from_ headi; keep going if there's only one
			# place to go to.
			adj = @cell_adj(headi)
			while true
				return false if adj.length == 0
				[aidx, adir] = adj[Math.random_int(adj.length)]
				@cells[headi].dir = adir
				@cells[aidx].num = @cells[headi].num + 1
				nfilled++
				headi = aidx
				adj = @cell_adj(headi)
				break unless adj.length == 1
			# Try and expand _to_ taili; keep going if there's only one
			# place to go to.
			adj = @cell_adj(taili)
			while true
				return false if adj.length == 0
				[aidx, adir] = adj[Math.random_int(adj.length)]
				@cells[aidx].dir = DIR_OPPOSITE(adir)
				@cells[aidx].num = @cells[taili].num - 1
				nfilled++
				taili = aidx
				adj = @cell_adj(taili)
				break unless adj.length == 1
		# If we get here we have headi and taili set but unconnected
		# by direction: we need to set headi's direction so as to point
		# at taili.
		@cells[headi].dir = @whichdiri(headi, taili)
		# it could happen that our last two weren't in line; if that's the
		# case, we have to start again.
		@cells[headi].dir != -1

	# Better generator: with the 'generate, sprinkle numbers, solve,
	# repeat' algorithm we're _never_ generating anything greater than
	# 6x6, and spending all of our time in new_game_fill (and very little
	# in solve_state).
	#
	# So, new generator steps:
	# generate the grid, at random (same as now). Numbers 1 and N get
	# immutable immediately.
	# squirrel that away for the solved state.
	#
	# (solve:) Try and solve it.
	#   If we solved it, we're done:
	#     generate the description from current immutable numbers,
	#     free stuff that needs freeing,
	#     return description + solved state.
	#   If we didn't solve it:
	#     count #tiles in state we've made deductions about.
	#     while (1):
	#       randomise a scratch array.
	#         for each index in scratch (in turn):
	#           if the cell isn't empty, continue (through scratch array)
	#           set number + immutable in state.
	#           try and solve state.
	#           if we've solved it, we're done.
	#           otherwise, count #tiles. If it's more than we had before:
	#             good, break from this loop and re-randomise.
	#           otherwise (number didn't help):
	#             remove number and try next in scratch array.
	#             if we've got to the end of the scratch array, no luck:
	#               free everything we need to, and go back to regenerate the grid.

	# Expects a fully-numbered game_state on input, and makes sure
	# immutable is only set on those numbers we need to solve
	# (as for a real new-game); returns 1 if it managed
	# this (such that it could solve it), or 0 if not.
	new_game_strip: ->
		copy = @clone()
		copy.strip_nums()
		return true if copy.solve_state()
		scratch = [0 .. @n - 1]
		scratch.shuffle()
		solved = do =>
			# This is scungy. It might just be quick enough.
			# It goes through, adding set numbers in empty squares
			# until either we run out of empty squares (in the one
			# we're half-solving) or else we solve it properly.
			# NB that we run the entire solver each time, which
			# strips the grid beforehand; we will save time if we
			# avoid that.
			for j in scratch
				if copy.cells[j].num > 0 and copy.cells[j].num <= @n
					continue # already solved to a real number here.
				copy.cells[j].num = @cells[j].num
				copy.cells[j].immutable = true
				@cells[j].immutable = true
				copy.strip_nums()
				cps = copy.solve_state()
				if cps
					copy = cps
					return true
			return false
		return false if not solved
		# Since we added basically at random, try now to remove numbers
		# and see if we can still solve it; if we can (still), really
		# remove the number. Make sure we don't remove the anchor numbers
		# 1 and N.
		for j in scratch
			if @cells[j].immutable and @cells[j].num != 1 and @cells[j].num != @n
				@cells[j].immutable = false
				copy = @clone()
				copy.strip_nums()
				cps = copy.solve_state()
				if not cps
					copy.cells[j].num = @cells[j].num
					@cells[j].immutable = true
				else
					copy = cps
		true

	connect_numbers: ->
		@dsf.constructor(@n)
		for cell, i in @cells
			if cell.next != -1
				di = @dsf.canonify(i)
				dni = @dsf.canonify(cell.next)
				if di == dni
					@impossible = 1
				@dsf.merge(di, dni)
		null

	# Assuming numbers are always up-to-date, there are only four possibilities
	# for regions changing after a single valid move:
	# 
	# 1) two differently-coloured regions being combined (the resulting colouring
	#  should be based on the larger of the two regions)
	# 2) a numbered region having a single number added to the start (the
	#  region's colour will remain, and the numbers will shift by 1)
	# 3) a numbered region having a single number added to the end (the
	#  region's colour and numbering remains as-is)
	# 4) two unnumbered squares being joined (will pick the smallest unused set
	#  of colours to use for the new region).
	# 
	# There should never be any complications with regions containing 3 colours
	# being combined, since two of those colours should have been merged on a
	# previous move.
	# 
	# Most of the complications are in ensuring we don't accidentally set two
	# regions with the same colour (e.g. if a region was split). If this happens
	# we always try and give the largest original portion the original colour.

	lowest_start: (heads) ->
		# NB start at 1: colour 0 is real numbers
		for c in [1 .. @n - 1]
			used = false
			for head in heads
				if @region_colour(head.start) == c
					used = true
					break
			return c if not used
		return 0

	update_numbers: ->
		@numsi.fill(-1)
		for cell, i in @cells
			if cell.immutable
				@numsi[cell.num] = i
			else if cell.prev == -1 and cell.next == -1
				cell.num = 0
		@connect_numbers()
		# Construct an array of the heads of all current regions, together
		# with their preferred colours.
		heads = for cell, i in @cells when not (cell.prev != -1 or cell.next == -1)
			# Look for a cell that is the start of a chain
			# (has a next but no prev).
			new head_meta(this, i)
		# Sort that array:
		# - heads with preferred colours first, then
		# - heads with low colours first, then
		# - large regions first
		heads.sort(compare_heads)
		# Remove duplicate-coloured regions.
		if heads.length > 0
			for n in [heads.length - 1 .. 0] # order is important!
				if n != 0 and heads[n].start == heads[n-1].start
					# We have a duplicate-coloured region: since we're
					# sorted in size order and this is not the first
					# of its colour it's not the largest: recolour it.
					heads[n].start = @region_start(@lowest_start(heads))
					heads[n].preference = -1 # '-1' means 'was duplicate'
				else if not heads[n].preference
					heads[n].start = @region_start(@lowest_start(heads))
		for head in heads
			nnum = head.start
			j = head.i
			while j != -1
				if not @cells[j].immutable
					if nnum > 0 and nnum <= @n
						@numsi[nnum] = j
					@cells[j].num = nnum
				nnum++
				j = @cells[j].next
		null

	check_completion: (mark_errors) ->
		error = false
		# NB This only marks errors that are possible to perpetrate with
		# the current UI in interpret_move. Things like forming loops in
		# linked sections and having numbers not add up should be forbidden
		# by the code elsewhere, so we don't bother marking those (because
		# it would add lots of tricky drawing code for very little gain).
		if mark_errors
			for c in @cells
				c.error = false
		# Search for repeated numbers.
		for cellj, j in @cells
			if cellj.num > 0 and cellj.num <= @n
				for cellk in @cells[j + 1 ..]
					if cellk.num == cellj.num
						if mark_errors
							cellj.error = true
							cellk.error = true
						error = true
		# Search and mark numbers n not pointing to n+1; if any numbers
		# are missing we know we've not completed.
		complete = true
		for n in [1 .. @n - 1]
			if @numsi[n] == -1 or @numsi[n + 1] == -1
				complete = false
			else if not @ispointingi(@numsi[n], @numsi[n + 1])
				if mark_errors
					@cells[@numsi[n]].error = true
					@cells[@numsi[n + 1]].error = true
				error = true
			else
				# make sure the link is explicitly made here; for instance, this
				# is nice if the user drags from 2 out (making 3) and a 4 is also
				# visible; this ensures that the link from 3 to 4 is also made.
				if mark_errors
					@makelink(@numsi[n], @numsi[n+1])
		# Search and mark numbers less than 0, or 0 with links.
		for cell in @cells
			if cell.num < 0 or (cell.num == 0 and (cell.next != -1 or cell.prev != -1))
				error = true
				if mark_errors
					cell.error = true
		return false if error
		return complete


	execute_move: (move) ->
		new_state = do =>
			if move[0] == 'L'
				[c, sx, sy, ex, ey] = move
				return null unless @isvalidmove(false, sx, sy, ex, ey)
				ret = @clone()
				ret.makelink(sy * @w + sx, ey * @w + ex)
				return ret
			else if move[0] == 'C' or move[0] == 'X'
				[c, sx, sy] = move
				if not @in_grid(sx, sy)
					return null
				si = sy * @w + sx
				return null if @cells[si].prev == -1 and @cells[si].next == -1
				if c == 'C'
					# Unlink the single cell we dragged from the board.
					ret = @clone()
					ret.unlink_cell(si)
					return ret
				else
					ret = @clone()
					sset = @region_colour(@cells[si].num)
					for i in [0 .. @n - 1]
						# Unlink all cells in the same set as the one we dragged
						# from the board.
						if @cells[i].num != 0 and sset == @region_colour(@cells[i].num)
							ret.unlink_cell(i)
					return ret
			else if move[0] == 'H'
				return @solve_state()
		if new_state
			new_state.update_numbers()
			if new_state.check_completion(true)
				new_state.completed = true
			return new_state
		else
			return null

	######## Solver #############

	# If a tile has a single tile it can link _to_, or there's only a single
	# location that can link to a given tile, fill that link in.
	solve_single: (copy) ->
		nlinks = 0
		# The from array is a list of 'which square can link _to_ us';
		# we start off with from as '-1' (meaning 'not found'); if we find
		# something that can link to us it is set to that index, and then if
		# we find another we set it to -2.
		from = (-1 for index in [1 .. @n])
		# poss is 'can I link to anything' with the same meanings.
		for i in [0 .. @n - 1]
			continue if @cells[i].next != -1
			continue if @cells[i].num == @n # no next from last no.
			d = @cells[i].dir
			poss = -1
			sx = x = 0|(i % @w)
			sy = y = 0|(i / @w)
			while true
				x += DIRECTION[d].x
				y += DIRECTION[d].y
				break if not @in_grid(x, y)
				continue if not @isvalidmove(true, sx, sy, x, y)
				# can't link to somewhere with a back-link we would have to
				# break (the solver just doesn't work like this).
				j = y * @w + x
				continue if @cells[j].prev != -1
				if @cells[i].num > 0 and @cells[j].num > 0 and @cells[i].num <= @n and @cells[j].num <= @n and @cells[j].num == @cells[i].num + 1
					poss = j
					from[j] = i
					break
				# if there's been a valid move already, we have to move on;
				# we can't make any deductions here.
				poss = if poss == -1 then j else -2
				# Modify the from array as described above (which is enumerating
				# what points to 'j' in a similar way).
				from[j] = if from[j] == -1 then i else -2
			if poss == -2
				# Multiple next squares
			else if poss == -1
				copy.impossible = 1
				return -1
			else
				copy.makelink(i, poss)
				nlinks++
		for i in [0 .. @n - 1]
			continue if @cells[i].prev != -1
			continue if @cells[i].num == 1 # no prev from 1st no.
			x = 0|(i % @w)
			y = 0|(i / @w)
			if from[i] == -1
				copy.impossible = 1
				return -1
			else if from[i] == -2
				# Multiple prev squares
			else
				copy.makelink(from[i], i)
				nlinks++
		return nlinks

	# Returns solved state if solution exists or null
	solve_state: ->
		state = @clone()
		copy = state.clone()
		while true
			state.update_numbers()
			if state.solve_single(copy)
				state = copy.clone()
				if state.impossible
					break
			else
				break
		state.update_numbers()
		if state.impossible
			throw 'impossible'
		else
			if state.check_completion(false)
				state
			else
				null



# --- Linked-list and numbers array --- 




class head_meta
	constructor: (state, @i) ->
		@start = null # region start number preferred, or 0 if !preference
		@sz = state.dsf.size(i) # size of region
		@why = null
		# Search through this chain looking for real numbers, checking that
		# they match up (if there are more than one).
		@preference = 0 # 0 if we have no preference (and should just pick one)
		j = @i
		offset = 0
		while j != -1
			if state.cells[j].immutable
				ss = state.cells[j].num - offset
				if not @preference
					@start = ss
					@preference = 1
					@why = 'contains cell with immutable number'
				else if @start != ss
					state.impossible = 1
			offset++
			j = state.cells[j].next
		return if @preference
		if state.cells[i].num == 0 and state.cells[state.cells[i].next].num > state.n
			# (probably) empty cell onto the head of a coloured region:
			# make sure we start at a 0 offset.
			@start = state.region_start(state.region_colour(state.cells[state.cells[i].next].num))
			@preference = 1
			@why = 'adding blank cell to head of numbered region'
		else if state.cells[i].num <= state.n
			# if we're 0 we're probably just blank -- but even if we're a
			# (real) numbered region, we don't have an immutable number
			# in it (any more) otherwise it'd have been caught above, so
			# reassign the colour.
			@start = 0
			@preference = 0
			@why = 'lowest available colour group'
		else
			c = state.region_colour(state.cells[i].num)
			n = 1
			sz = state.dsf.size(i)
			j = i
			while state.cells[j].next != -1
				j = state.cells[j].next
				if state.cells[j].num == 0 and state.cells[j].next == -1
					@start = state.region_start(c)
					@preference = 1
					@why = 'adding blank cell to end of numbered region'
					return
				if state.region_colour(state.cells[j].num) == c
					n++
				else
					start_alternate = state.region_start(state.region_colour(state.cells[j].num))
					if n < (sz - n)
						@start = start_alternate
						@preference = 1
						@why = 'joining two coloured regions, swapping to larger colour'
					else
						@start = state.region_start(c)
						@preference = 1
						@why = 'joining two coloured regions, taking largest'
					return
			# If we got here then we may have split a region into
			# two; make sure we don't assign a colour we've already used. */
			if c == 0
				@start = 0
				@preference = 0
			else
				@start = state.region_start(c)
				@preference = 1
			@why = 'got to end of coloured region'

compare_heads = (ha, hb) ->
	# Heads with preferred colours first...
	return -1 if ha.preference and not hb.preference
	return 1 if hb.preference and not ha.preference
	# ...then heads with low colours first...
	return -1 if ha.start < hb.start
	return 1 if ha.start > hb.start
	# ... then large regions first...
	return -1 if ha.sz > hb.sz
	return 1 if ha.sz < hb.sz
	# ... then position.
	return -1 if ha.i > hb.i
	return 1 if ha.i < hb.i
	return 0




LEFT_BUTTON = 1
MIDDLE_BUTTON = 2
RIGHT_BUTTON = 3
LEFT_DRAG = 4
MOUSE_DRAG = 5
MOUSE_RELEASE = 7
CURSOR_UP = 10
CURSOR_DOWN = 11
CURSOR_LEFT = 12
CURSOR_RIGHT = 13
CURSOR_SELECT = 14
CURSOR_SELECT2 = 15

IS_MOUSE_DOWN = (m) ->
	m - LEFT_BUTTON <= RIGHT_BUTTON - LEFT_BUTTON
IS_CURSOR_MOVE = (m) ->
	m == CURSOR_UP || m == CURSOR_DOWN || m == CURSOR_RIGHT || m == CURSOR_LEFT
IS_CURSOR_SELECT = (m) ->
	m == CURSOR_SELECT || m == CURSOR_SELECT2


class GameUI
	constructor: () ->
		@cx = @cy = 0
		@cshow = false
		@dragging = false
		@sx = @sy = 0 # grid coords of start cell
		@dx = @dy = 0 # grid coords of drag posn
		@drag_is_from = false

	# returns a move object to be passed to state.execute_move()
	interpret_cursor: (state, ds, button) ->
		if IS_CURSOR_MOVE(button)
			switch button
				when CURSOR_UP
					@cy = (@cy - 1 + state.h) % state.h
				when CURSOR_DOWN
					@cy = (@cy + 1) % state.h
				when CURSOR_LEFT
					@cx = (@cx - 1 + state.w) % state.w
				when CURSOR_RIGHT
					@cx = (@cx + 1) % state.w
			@cshow = true
			if @dragging
				[@dx, @dy] = ds.cell_center(@cx, @cy)
			null
		else if IS_CURSOR_SELECT(button)
			if not @cshow
				@cshow = true
			if @dragging
				@dragging = false
				if @sx == @cx and @sy == @cy
					null
				else if @drag_is_from
					if not state.isvalidmove(false, @sx, @sy, @cx, @cy)
						null
					else
						['L', @sx, @sy, @cx, @cy]
				else
					if not state.isvalidmove(false, @cx, @cy, @sx, @sy)
						null
					else
						['L', @cx, @cy, @sx, @sy]
			else
				@dragging = true
				@sx = @cx
				@sy = @cy
				[@dx, @dy] = ds.cell_center(@cx, @cy)
				@drag_is_from = (button == CURSOR_SELECT)
				null
	
	interpret_mouse_down: (state, ds, mx, my, button) ->
		[x, y] = ds.cell_at(mx, my)
		index = y * state.w + x
		if @cshow
			@cshow = @dragging = false
		if not state.in_grid(x, y)
			return null
		if button == LEFT_BUTTON
			# disallow dragging from the final number.
			if (state.cells[index].num == state.n) and state.cells[index].immutable
				return null
		else if button == RIGHT_BUTTON
			# disallow dragging to the first number.
			if (state.cells[index].num == 1) and state.cells[index].immutable
				return null
		@dragging = true
		@drag_is_from = (button == LEFT_BUTTON)
		@sx = x
		@sy = y
		@dx = mx
		@dy = my
		@cshow = false
		null

	interpret_mouse_drag: (mx, my) ->
		if @dragging
			@dx = mx
			@dy = my
		null

	interpret_mouse_drag_release: (state, ds, mx, my) ->
		[x, y] = ds.cell_at(mx, my)
		if @sx == x and @sy == y
			null # single click
		else if not state.in_grid(x, y)
			si = @sy * state.w + @sx
			if state.cells[si].prev == -1 and state.cells[si].next == -1
				null
			else
				[(if @drag_is_from then 'C' else 'X'), @sx, @sy]
		else if @drag_is_from
			if not state.isvalidmove(false, @sx, @sy, x, y)
				null
			else
				['L', @sx, @sy, x, y]
		else
			if not state.isvalidmove(false, x, y, @sx, @sy)
				null
			else
				['L', x, y, @sx, @sy]

	interpret_move: (state, ds, mx, my, button) ->
		if IS_CURSOR_MOVE(button)
			@interpret_cursor(state, ds, button)
		else if IS_CURSOR_SELECT(button)
			@interpret_cursor(state, ds, button)
		else if IS_MOUSE_DOWN(button)
			@interpret_mouse_down(state, ds, mx, my, button)
		else if button == MOUSE_DRAG
			@interpret_mouse_drag(mx, my)
		else if button == MOUSE_RELEASE and @dragging
			@dragging = false
			@interpret_mouse_drag_release(state, ds, mx, my)
		else if (button == 'x' or button == 'X') and @cshow
			si = @cy * state.w + @cx
			if state.cells[si].prev == -1 and state.cells[si].next == -1
				null
			else
				[(if button == 'x' then 'C' else 'X'), @cx, @cy]
		else
			null


############## Drawing #################

Color = net.brehaut.Color

ALPHABET = 'abcdefghijklmnopqrstuvwxyz'
COL_BACKGROUND = '#eeeeee'
COL_GRID = '#cccccc'
COL_ARROW = '#000000'
COL_NUMBER_SET = '#0000ff'
COL_NUMBER = '#000000'
COL_CURSOR = '#000'
COL_DRAG_ORIGIN = 'blue'
COL_ERROR = 'red'

ALPHA_DIM = 0.2
ALPHA_ARROW = 0.3





region_color = (set) ->
	hue = 0
	step = 60
	shift = step
	for k in [0 .. set]
		hue += step
		if hue >= 360
			hue -= 360
			shift /= 2
			hue += shift
	Color({hue: hue, saturation: 0.3, value: 1}).toCSS()

class CanvasPainter
	constructor: (@dr) ->
		null

	# return coordinate of tile center from index
	cell_center: (cx, cy) ->
		[x, y] = @cell_coord(cx, cy)
		[x + @tilesize / 2, y + @tilesize / 2]
		
	# return coordinate of upper left corner
	cell_coord: (x, y) ->
		[x * @tilesize + @center_x, y * @tilesize + @center_y]

	# return cell index for coordinate
	cell_at: (x, y) ->
		[
			Math.floor((x + @tilesize - @center_x) / @tilesize) - 1
			Math.floor((y + @tilesize - @center_y) / @tilesize) - 1
		]

	# cx, cy are top-left corner. r is the 'radius' of the arrow.
	# ang is in radians, clockwise from 0 == straight up.
	draw_arrow: (cx, cy, r, ang, cfill) ->
		@dr.save()
		@dr.translate cx, cy
		@dr.rotate ang
		p = r * 0.4
		@dr.beginPath()
		@dr.moveTo 0, -r
		@dr.lineTo r, 0
		@dr.lineTo p, 0
		@dr.lineTo p, r
		@dr.lineTo -p, r
		@dr.lineTo -p, 0
		@dr.lineTo -r, 0
		@dr.fillStyle = cfill
		@dr.fill()
		@dr.restore()
		null

	# cx, cy are centre coordinates..
	draw_star: (cx, cy, rad, npoints, cfill) ->
		@dr.save()
		@dr.translate(cx, cy)
		fun = 'moveTo'
		@dr.beginPath()
		for n in [0 .. npoints * 2 - 1]
			a = 2.0 * Math.PI * (n / (npoints * 2.0))
			r = if 0|(n % 2) then rad/2.0 else rad
			# We're rotating the poat (0, -r) by a degrees
			@dr[fun](r * Math.sin(a), -r * Math.cos(a))
			fun = 'lineTo'
		@dr.fillStyle = cfill
		@dr.fill()
		@dr.restore()
		null



	game_redraw: (state, ui) ->
		@dr.canvas.width = @dr.canvas.width
		cw = @dr.canvas.width
		ch = @dr.canvas.height
		tsx = (cw * 0.8) / state.w
		tsy = (ch * 0.8) / state.h
		@tilesize = Math.floor(Math.min(80,Math.min(tsx, tsy)))
		@arrow_size = 7 * @tilesize / 32
		@center_x = 0|((cw - state.w * @tilesize) / 2)
		@center_y = 0|((ch - state.h * @tilesize) / 3)

		postdrop = null
		# If an in-progress drag would make a valid move if finished, we
		# reflect that move in the board display. We let interpret_move do
		# most of the heavy lifting for us: we have to copy the GameUI so
		# as not to stomp on the real UI's drag state.
		if ui.dragging
			move = ui.interpret_mouse_drag_release(state, this, ui.dx, ui.dy)
			if move
				state = postdrop = state.execute_move(move)
		aw = @tilesize * state.w
		ah = @tilesize * state.h
		@dr.fillStyle = COL_BACKGROUND
		[bgx, bgy] = @cell_coord(0, 0)
		@dr.fillRect(bgx, bgy, aw, ah)
		for x in [0 .. state.w - 1]
			for y in [0 .. state.h - 1]
				@dr.save()
				@dr.translate @cell_coord(x, y)...
				cell = state.cells[x + y * state.w]
				arrowcol = COL_ARROW
				if ui.dragging
					if x == ui.sx and y == ui.sy
						arrowcol = COL_DRAG_ORIGIN
					else if ui.drag_is_from
						if not state.ispointing(ui.sx, ui.sy, x, y)
							@dr.globalAlpha = ALPHA_DIM
					else if not state.ispointing(x, y, ui.sx, ui.sy)
						@dr.globalAlpha = ALPHA_DIM
				arrow_out = cell.next != -1
				arrow_in = cell.prev != -1
				# We don't display text in empty cells: typically these are
				# signified by num=0. However, in some cases a cell could
				# have had the number 0 assigned to it if the user made an
				# error (e.g. tried to connect a chain of length 5 to the
				# immutable number 4) so we _do_ display the 0 if the cell
				# has a link in or a link out.
				empty = cell.num == 0 and not arrow_out and not arrow_in
				# Clear tile background
				@dr.fillStyle =
					if empty
						COL_BACKGROUND
					else
						region = state.region_colour(cell.num)
						if cell.num <= 0 or region == 0
							'#fff'
						else
							region_color(region)
				@dr.fillRect(0, 0, @tilesize, @tilesize)
				## Draw arrow or star
				@dr.save()
				if arrow_out
					@dr.globalAlpha = Math.min(@dr.globalAlpha, ALPHA_ARROW)
				# Draw large (outwards-pointing) arrow.
				acx = @tilesize/2 + @arrow_size # centre x
				acy = @tilesize/2 + @arrow_size # centre y
				if cell.num == state.n and cell.immutable
					@draw_star(acx, acy, @arrow_size, 5, arrowcol)
				else
					@draw_arrow(acx, acy, @arrow_size, dir_angle(cell.dir), arrowcol)
				if ui.cshow and x == ui.cx and y == ui.cy
					@dr.save()
					@dr.translate(0.5, 0.5)
					@dr.beginPath()
					m = 1
					s = @arrow_size + 2 * m
					b = s / 2
					for i in [0 .. 3]
						@dr.save()
						@dr.translate acx - m, acy - m
						@dr.rotate i * Math.PI / 2
						@dr.moveTo s, s - b
						@dr.lineTo s, s
						@dr.lineTo s - b, s
						@dr.restore()
					@dr.strokeStyle = COL_CURSOR
					@dr.stroke()
					@dr.restore()
				@dr.restore()
				# Draw dot iff this tile requires a predecessor and doesn't have one.
				if not arrow_in and cell.num != 1
					@dr.beginPath()
					@dr.arc @tilesize/2 - @arrow_size, @tilesize/2 + @arrow_size, @arrow_size / 4, 0, 2 * Math.PI, false
					@dr.fillStyle = COL_ARROW
					@dr.fill()
				# Draw text (number or set).
				@dr.save()
				if (arrow_in and arrow_out) or (cell.num == state.n) or (cell.num == 1)
					@dr.globalAlpha = Math.min(@dr.globalAlpha, ALPHA_ARROW)
				if not empty
					set = if cell.num <= 0 then 0 else state.region_colour(cell.num)
					@dr.fillStyle =
						if cell.immutable
							COL_NUMBER_SET
						else if state.impossible or cell.num < 0 or cell.error
							COL_ERROR
						else
							COL_NUMBER
					if set == 0 or cell.num <= 0
						buf = "#{cell.num}"
						@dr.font = "bold #{@tilesize * 0.4}px sans-serif"
						@dr.fillText(buf, @tilesize * 0.1, @tilesize * 0.4)
					else
						buf = ''
						while set > 0
							set--
							buf += ALPHABET[0|(set % ALPHABET.length)]
							set = 0|(set / 26)
						n = 0|(cell.num % (state.n + 1))
						if n != 0
							buf += "+#{n}"
						@dr.font = "#{@tilesize * 0.35}px sans-serif"
						@dr.fillText(buf, @tilesize * 0.1, @tilesize * 0.4)
				@dr.restore()
				@dr.globalAlpha = 1
				@dr.translate(0.5, 0.5)
				@dr.strokeStyle = COL_GRID
				@dr.strokeRect(0, 0, @tilesize, @tilesize)
				@dr.restore()
		if ui.dragging
			if postdrop?
				# If we could move here, lock the arrow to the appropriate direction.
				if ui.drag_is_from
					dir = state.cells[ui.sy * state.w + ui.sx].dir 
				else
					[fx, fy] = @cell_at(ui.dx, ui.dy)
					dir = state.cells[fy * state.w + fx].dir
				ang = dir_angle(dir)
			else
				# Draw an arrow pointing away from/towards the origin cell.
				[ox, oy] = @cell_center(ui.sx, ui.sy)
				ang = point_angle(ox, oy, ui.dx, ui.dy)
				if not ui.drag_is_from
					ang += Math.PI # poto origin, not away from.
			@draw_arrow(ui.dx, ui.dy, @arrow_size, ang, COL_ARROW)
	null

handle = (e, l, f) ->
	e.addEventListener(l, f, false)

handle window, 'load', ->
	ui = new GameUI()
	canvas = document.getElementById 'game'
	canvas.style.display = 'block'
	canvas.width = window.innerWidth
	canvas.height = window.innerHeight
	ctx = canvas.getContext '2d'
	ds = new CanvasPainter(ctx)

	setup = document.getElementById 'setup'
	setup_width = document.getElementById 'width'
	setup_height = document.getElementById 'height'
	play_button = document.getElementById 'play'
	won = document.getElementById 'won'
	again_button = document.getElementById 'again'
	corner_start = document.getElementById 'corner_start'
	fail = document.getElementById 'fail'
	fail.style.display = 'none'

	handle again_button, 'click', ->
		won.style.display = 'none'
		setup.style.display = 'block'

	setup.style.display = 'block'

	params = new GameParams(6, 6, true)
	states = []
	current_state = 0

	draw = ->
		if 0 <= current_state < states.length
			ds.game_redraw(states[current_state], ui)

	start_game = ->
		w = 0| +setup_width.value
		h = 0| +setup_height.value
		c = !!+corner_start.value
		if 3 <= w <= 50 and 3 <= h <= 50
			params = new GameParams(w, h, c)
			states = [params.new_game()]
			current_state = 0
			draw()

	handle play_button, 'click', ->
		start_game()
		setup.style.display = 'none'

	x = y = 0
	make_move = (button) ->
		if 0 <= current_state < states.length and not states[current_state].completed
			mov = ui.interpret_move(states[current_state], ds, x, y, button)
			if mov
				new_state = states[current_state].execute_move(mov)
				states = states[..current_state]
				states.push(new_state)
				current_state++
			draw()
			if states[current_state].completed
				won.style.display = 'block'

	undo_move = ->
		if current_state > 0
			current_state--
			draw()
			true
		else
			false

	redo_move = ->
		if current_state < states.length - 1
			current_state++
			draw()
			true
		else
			false

	handle window, 'keydown', (event) ->
		switch event.keyCode
			when 37, 65 # left, a: move cursor
				make_move(CURSOR_LEFT)
				event.preventDefault()
			when 38, 87 # up, w: move cursor
				make_move(CURSOR_UP)
				event.preventDefault()
			when 39, 68 # right, d: move cursor
				make_move(CURSOR_RIGHT)
				event.preventDefault()
			when 40, 83 # down, s: move cursor
				make_move(CURSOR_DOWN)
				event.preventDefault()
			when 32 # space: forward select
				make_move(CURSOR_SELECT)
				event.preventDefault()
			when 13 # enter: reverse select
				make_move(CURSOR_SELECT2)
				event.preventDefault()
			when 85 # u: undo
				if undo_move()
					event.preventDefault()
			when 82 # r: redo
				if redo_move()
					event.preventDefault()
	
	handle canvas, 'contextmenu', (event) ->
		event.stopImmediatePropagation?()
		event.preventDefault()

	mouse_is_down = false
	handle canvas, 'mousedown', (event) ->
		mouse_is_down = true
		event.stopImmediatePropagation?()
		event.preventDefault()
		x = event.clientX
		y = event.clientY
		switch event.button
			when 0
				make_move(LEFT_BUTTON)
			when 1
				make_move(MIDDLE_BUTTON)
			when 2
				make_move(RIGHT_BUTTON)
	
	handle canvas, 'mouseup', (event) ->
		mouse_is_down = false
		event.stopImmediatePropagation?()
		event.preventDefault()
		x = event.clientX
		y = event.clientY
		make_move(MOUSE_RELEASE)
	
	handle window, 'mouseup', (event) ->
		mouse_is_down = false
		make_move(MOUSE_RELEASE)

	handle canvas, 'mousemove', (event) ->
		if mouse_is_down
			event.preventDefault()
			x = event.clientX
			y = event.clientY
			make_move(MOUSE_DRAG)

	handle window, 'resize', (event) ->
		canvas.width = window.innerWidth
		canvas.height = window.innerHeight
		draw()

	draw()
