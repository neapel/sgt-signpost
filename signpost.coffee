# signpost.c: implementation of the janko game 'arrow path'

Math.seedrandom('foo')

class game_params
	constructor: (@w, @h, @force_corner_start) ->
		throw 'W, H must at least be 2' if @w < 2 or @h < 2
		throw 'One must at least be 3' if @w == 2 and @h == 2
		null

DIR_N = 0
DIR_NE = 1
DIR_E = 2
DIR_SE = 3
DIR_S = 4
DIR_SW = 5
DIR_W = 6
DIR_NW = 7
DIR_MAX = 8
dirstrings = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']
dxs = [  0,  1, 1, 1, 0, -1, -1, -1 ]
dys = [ -1, -1, 0, 1, 1,  1,  0, -1 ]

DIR_OPPOSITE = (d) -> 0|((d + 4) % 8)

whichdir = (fromx, fromy, tox, toy) ->
	dx = tox - fromx
	dy = toy - fromy
	if dx and dy and Math.abs(dx) != Math.abs(dy)
		return -1
	if dx
		dx = dx / Math.abs(dx) # limit to (-1, 0, 1)
	if dy
		dy = dy / Math.abs(dy) # ditto
	for i in [0 .. DIR_MAX - 1]
		if dx == dxs[i] and dy == dys[i]
			return i
	return -1

FLAG_IMMUTABLE = 1
FLAG_ERROR = 2

# Generally useful functions


# --- Game description string generation and unpicking ---

generate_desc = (state) ->
	descs =
		for i in [0 .. state.n - 1]
			if state.nums[i]
				"#{state.nums[i]}:#{state.dirs[i]}"
			else
				"#{state.dirs[i]}"
	descs.join(',')




class game_state
	constructor: (@w, @h) ->
		@n = @w * @h
		@completed = @used_solve = @impossible = false #int
		@dirs = snewn(@n) # direction enums, size n int*
		@nums = snewn(@n) # numbers, size n, int*
		@flags = snewn(@n) # flags, size n, uint*
		@next = snewn(@n)
		@prev = snewn(@n) # links to other cell indexes, size n (-1 absent)
		@dsf = new DisjointSetForest(@n) # connects regions with a dsf.
		@numsi = snewn(@n + 1) # for each number, which index is it in? (-1 absent)
		@blank()

	blank: ->
		@dirs.fill(0)
		@nums.fill(0)
		@flags.fill(0)
		@next.fill(-1)
		@prev.fill(-1)
		@numsi.fill(-1)
		null

	clone: ->
		to = new game_state(@w, @h)
		to.completed = @completed
		to.used_solve = @used_solve
		to.impossible = @impossible
		for i in [0 .. @n - 1]
			to.dirs[i] = @dirs[i]
			to.flags[i] = @flags[i]
			to.nums[i] = @nums[i]
			to.next[i] = @next[i]
			to.prev[i] = @prev[i]
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
		dir = @dirs[fromy * @w + fromx]
		# (by convention) squares do not poto themselves.
		if fromx == tox and fromy == toy
			return false
		# the final number points to nothing.
		if @nums[fromy * @w + fromx] == @n
			return false
		while true
			if not @in_grid(fromx, fromy)
				return false
			if fromx == tox and fromy == toy
				return true
			fromx += dxs[dir]
			fromy += dys[dir]
		null # not reached

	ispointingi: (fromi, toi) ->
		@ispointing(0|(fromi % @w), 0|(fromi / @w), 0|(toi % @w), 0|(toi / @w))

	# Taking the number 'num', work out the gap between it and the next
	# available number up or down (depending on d). Return 1 if the region
	# at (x,y) will fit in that gap, or 0 otherwise.
	move_couldfit: (num, d, x, y) ->
		i = y * @w + x
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
			@nums[i] != num + d
		else if @prev[i] == -1 and @next[i] == -1
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
		nfrom = @nums[from]
		nto = @nums[to]
		# can't move _from_ the preset final number, or _to_ the preset 1.
		return false if nfrom == @n and (@flags[from] & FLAG_IMMUTABLE)
		return false if nto == 1 and (@flags[to] & FLAG_IMMUTABLE)
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
		if @next[from] != -1
			@prev[@next[from]] = -1
		@next[from] = to
		if @prev[to] != -1
			@next[@prev[to]] = -1
		@prev[to] = from
		null

	unlink_cell: (si) ->
		if @prev[si] != -1
			@next[@prev[si]] = -1
			@prev[si] = -1
		if @next[si] != -1
			@prev[@next[si]] = -1
			@next[si] = -1
		null

	strip_nums: ->
		for i in [0 .. @n - 1]
			if not (@flags[i] & FLAG_IMMUTABLE)
				@nums[i] = 0
		@next.fill(-1)
		@prev.fill(-1)
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
		for a in [0 .. DIR_MAX - 1]
			x = sx
			y = sy
			dx = dxs[a]
			dy = dys[a]
			while true
				x += dx
				y += dy
				break unless @in_grid(x, y)
				newi = y * @w + x
				if @nums[newi] == 0
					adjacent.push [newi, a]
		adjacent

	new_game_fill: (headi, taili) ->
		@nums.fill(0)
		@nums[headi] = 1
		@nums[taili] = @n
		@dirs[taili] = 0
		nfilled = 2
		while nfilled < @n
			# Try and expand _from_ headi; keep going if there's only one
			# place to go to.
			adj = @cell_adj(headi)
			while true
				return false if adj.length == 0
				[aidx, adir] = adj[Math.random_int(adj.length)]
				@dirs[headi] = adir
				@nums[aidx] = @nums[headi] + 1
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
				@dirs[aidx] = DIR_OPPOSITE(adir)
				@nums[aidx] = @nums[taili] - 1
				nfilled++
				taili = aidx
				adj = @cell_adj(taili)
				break unless adj.length == 1
		# If we get here we have headi and taili set but unconnected
		# by direction: we need to set headi's direction so as to point
		# at taili.
		@dirs[headi] = @whichdiri(headi, taili)
		# it could happen that our last two weren't in line; if that's the
		# case, we have to start again.
		@dirs[headi] != -1

	# Better generator: with the 'generate, sprinkle numbers, solve,
	# repeat' algorithm we're _never_ generating anything greater than
	# 6x6, and spending all of our time in new_game_fill (and very little
	# in solve_state).
	#
	# So, new generator steps:
	# generate the grid, at random (same as now). Numbers 1 and N get
	# immutable flag immediately.
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
	# FLAG_IMMUTABLE is only set on those numbers we need to solve
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
				if copy.nums[j] > 0 and copy.nums[j] <= @n
					continue # already solved to a real number here.
				copy.nums[j] = @nums[j]
				copy.flags[j] |= FLAG_IMMUTABLE
				@flags[j] |= FLAG_IMMUTABLE
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
			if (@flags[j] & FLAG_IMMUTABLE) and @nums[j] != 1 and @nums[j] != @n
				@flags[j] &= ~FLAG_IMMUTABLE
				copy = @clone()
				copy.strip_nums()
				cps = copy.solve_state()
				if not cps
					copy.nums[j] = @nums[j]
					@flags[j] |= FLAG_IMMUTABLE
				else
					copy = cps
		true

	connect_numbers: ->
		@dsf.constructor(@n)
		for i in [0 .. @n - 1]
			if @next[i] != -1
				di = @dsf.canonify(i)
				dni = @dsf.canonify(@next[i])
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
		for i in [0 .. @n - 1]
			if @flags[i] & FLAG_IMMUTABLE
				@numsi[@nums[i]] = i
			else if @prev[i] == -1 and @next[i] == -1
				@nums[i] = 0
		@connect_numbers()
		# Construct an array of the heads of all current regions, together
		# with their preferred colours.
		heads = for i in [0 .. @n - 1] when not (@prev[i] != -1 or @next[i] == -1)
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
				if not (@flags[j] & FLAG_IMMUTABLE)
					if nnum > 0 and nnum <= @n
						@numsi[nnum] = j
					@nums[j] = nnum
				nnum++
				j = @next[j]
		null

	check_completion: (mark_errors) ->
		error = false
		# NB This only marks errors that are possible to perpetrate with
		# the current UI in interpret_move. Things like forming loops in
		# linked sections and having numbers not add up should be forbidden
		# by the code elsewhere, so we don't bother marking those (because
		# it would add lots of tricky drawing code for very little gain).
		if mark_errors
			for j in [0 .. @n - 1]
				@flags[j] &= ~FLAG_ERROR
		# Search for repeated numbers.
		for j in [0 .. @n - 1]
			if @nums[j] > 0 and @nums[j] <= @n
				for k in [j + 1 .. @n - 1] by 1
					if @nums[k] == @nums[j]
						if mark_errors
							@flags[j] |= FLAG_ERROR
							@flags[k] |= FLAG_ERROR
						error = true
		# Search and mark numbers n not pointing to n+1; if any numbers
		# are missing we know we've not completed.
		complete = true
		for n in [1 .. @n - 1]
			if @numsi[n] == -1 or @numsi[n + 1] == -1
				complete = false
			else if not @ispointingi(@numsi[n], @numsi[n + 1])
				if mark_errors
					@flags[@numsi[n]] |= FLAG_ERROR
					@flags[@numsi[n + 1]] |= FLAG_ERROR
				error = true
			else
				# make sure the link is explicitly made here; for instance, this
				# is nice if the user drags from 2 out (making 3) and a 4 is also
				# visible; this ensures that the link from 3 to 4 is also made.
				if mark_errors
					@makelink(@numsi[n], @numsi[n+1])
		# Search and mark numbers less than 0, or 0 with links.
		for n in [1 .. @n - 1]
			if @nums[n] < 0 or (@nums[n] == 0 and (@next[n] != -1 or @prev[n] != -1))
				error = true
				if mark_errors
					@flags[n] |= FLAG_ERROR
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
				return null if @prev[si] == -1 and @next[si] == -1
				if c == 'C'
					# Unlink the single cell we dragged from the board.
					ret = @clone()
					ret.unlink_cell(si)
					return ret
				else
					ret = @clone()
					sset = @region_colour(@nums[si])
					for i in [0 .. @n - 1]
						# Unlink all cells in the same set as the one we dragged
						# from the board.
						if @nums[i] != 0 and sset == @region_colour(@nums[i])
							ret.unlink_cell(i)
					return ret
			else if move[0] == 'H'
				ret = @clone()
				ret = ret.solve_state()
				return ret
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
			continue if @next[i] != -1
			continue if @nums[i] == @n # no next from last no.
			d = @dirs[i]
			poss = -1
			sx = x = 0|(i % @w)
			sy = y = 0|(i / @w)
			while true
				x += dxs[d]
				y += dys[d]
				break if not @in_grid(x, y)
				continue if not @isvalidmove(true, sx, sy, x, y)
				# can't link to somewhere with a back-link we would have to
				# break (the solver just doesn't work like this).
				j = y * @w + x
				continue if @prev[j] != -1
				if @nums[i] > 0 and @nums[j] > 0 and @nums[i] <= @n and @nums[j] <= @n and @nums[j] == @nums[i] + 1
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
		for i in [0 .. @n]
			continue if @prev[i] != -1
			continue if @nums[i] == 1 # no prev from 1st no.
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

new_game = (params) ->
	state = new game_state(params.w, params.h)
	for x in [0 .. 50]
		state.blank()
		# keep trying until we fill successfully.
		while true
			if params.force_corner_start
				headi = 0
				taili = state.n-1
			else
				while true
					headi = Math.random_int(state.n)
					taili = Math.random_int(state.n)
					break unless headi == taili
			break if state.new_game_fill(headi, taili)
		state.flags[headi] |= FLAG_IMMUTABLE
		state.flags[taili] |= FLAG_IMMUTABLE
		# This will have filled in directions and _all_ numbers.
		# Store the game definition for this, as the solved-state.
		if state.new_game_strip()
			state.strip_nums()
			state.update_numbers()
			state.check_completion(true) # update any auto-links
			return state
	throw 'Game generation failed.'


# --- Linked-list and numbers array --- 




class head_meta
	constructor: (state, i) ->
		@start = null # region start number preferred, or 0 if !preference
		@i = i # position
		@sz = state.dsf.size(i) # size of region
		@why = null
		# Search through this chain looking for real numbers, checking that
		# they match up (if there are more than one).
		@preference = 0 # 0 if we have no preference (and should just pick one)
		j = i
		offset = 0
		while j != -1
			if state.flags[j] & FLAG_IMMUTABLE
				ss = state.nums[j] - offset
				if not @preference
					@start = ss
					@preference = 1
					@why = 'contains cell with immutable number'
				else if @start != ss
					state.impossible = 1
			offset++
			j = state.next[j]
		return if @preference
		if state.nums[i] == 0 and state.nums[state.next[i]] > state.n
			# (probably) empty cell onto the head of a coloured region:
			# make sure we start at a 0 offset.
			@start = state.region_start(state.region_colour(state.nums[state.next[i]]))
			@preference = 1
			@why = 'adding blank cell to head of numbered region'
		else if state.nums[i] <= state.n
			# if we're 0 we're probably just blank -- but even if we're a
			# (real) numbered region, we don't have an immutable number
			# in it (any more) otherwise it'd have been caught above, so
			# reassign the colour.
			@start = 0
			@preference = 0
			@why = 'lowest available colour group'
		else
			c = state.region_colour(state.nums[i])
			n = 1
			sz = state.dsf.size(i)
			j = i
			while state.next[j] != -1
				j = state.next[j]
				if state.nums[j] == 0 and state.next[j] == -1
					@start = state.region_start(c)
					@preference = 1
					@why = 'adding blank cell to end of numbered region'
					return
				if state.region_colour(state.nums[j]) == c
					n++
				else
					start_alternate = state.region_start(state.region_colour(state.nums[j]))
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

# --- Solver ---




LEFT_BUTTON = 1
MIDDLE_BUTTON = 2
RIGHT_BUTTON = 3
LEFT_DRAG = 4
MIDDLE_DRAG = 5
RIGHT_DRAG = 6
LEFT_RELEASE = 7
MIDDLE_RELEASE = 8
RIGHT_RELEASE = 9
CURSOR_UP = 10
CURSOR_DOWN = 11
CURSOR_LEFT = 12
CURSOR_RIGHT = 13
CURSOR_SELECT = 14
CURSOR_SELECT2 = 15

IS_MOUSE_DOWN = (m) ->
	m - LEFT_BUTTON <= RIGHT_BUTTON - LEFT_BUTTON
IS_MOUSE_DRAG = (m) ->
	m - LEFT_DRAG <= RIGHT_DRAG - LEFT_DRAG
IS_MOUSE_RELEASE = (m) ->
	m - LEFT_RELEASE <= RIGHT_RELEASE - LEFT_RELEASE
IS_CURSOR_MOVE = (m) ->
	m == CURSOR_UP || m == CURSOR_DOWN || m == CURSOR_RIGHT || m == CURSOR_LEFT
IS_CURSOR_SELECT = (m) ->
	m == CURSOR_SELECT || m == CURSOR_SELECT2


class game_ui
	constructor: () ->
		@cx = @cy = 0
		@cshow = false
		@dragging = 0
		@sx = @sy = 0 # grid coords of start cell
		@dx = @dy = 0 # grid coords of drag posn
		@drag_is_from = false

	clone: ->
		g = new game_ui()
		g.cx = @cx
		g.cy = @cy
		g.cshow = @cshow
		g.dragging = @dragging
		g.sx = @sx
		g.sy = @sy
		g.dx = @dx
		g.dy = @dy
		g.drag_is_from = @drag_is_from
		g

	game_changed_state: (oldstate, newstate) ->
		if not oldstate.completed and newstate.completed
			@cshow = @dragging = 0
		null

	# returns a move object to be passed to state.execute_move()
	interpret_move: (state, ds, mx, my, button) ->
		[x, y] = ds.cell_at(mx, my)
		w = state.w
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
		else if IS_MOUSE_DOWN(button)
			if @cshow
				@cshow = @dragging = false
			if not state.in_grid(x, y)
				return null
			if button == LEFT_BUTTON
				# disallow dragging from the final number.
				if (state.nums[y*w+x] == state.n) and (state.flags[y*w+x] & FLAG_IMMUTABLE)
					return null
			else if button == RIGHT_BUTTON
				# disallow dragging to the first number.
				if (state.nums[y*w+x] == 1) and (state.flags[y*w+x] & FLAG_IMMUTABLE)
					return null
			@dragging = true
			@drag_is_from = (button == LEFT_BUTTON)
			@sx = x
			@sy = y
			@dx = mx
			@dy = my
			@cshow = false
			null
		else if IS_MOUSE_DRAG(button) and @dragging
			@dx = mx
			@dy = my
			null
		else if IS_MOUSE_RELEASE(button) and @dragging
			@dragging = false
			if @sx == x and @sy == y
				null # single click
			else if not state.in_grid(x, y)
				si = @sy * w + @sx
				if state.prev[si] == -1 and state.next[si] == -1
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
		else if (button == 'x' or button == 'X') and @cshow
			si = @cy * w + @cx
			if state.prev[si] == -1 and state.next[si] == -1
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



F_CUR = 0x001 # Cursor on this tile.
F_DRAG_SRC = 0x002 # Tile is source of a drag.
F_ERROR = 0x004 # Tile marked in error.
F_IMMUTABLE = 0x008 # Tile (number) is immutable.
F_ARROW_POINT = 0x010 # Tile points to other tile
F_ARROW_INPOINT = 0x020 # Other tile points in here.
F_DIM = 0x040 # Tile is dim


set_color = (set) ->
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


dim = (a, b) ->
	Color(a).blend(Color(b), 0.5).toCSS()
mid = (a, b) ->
	dim(a, b)
dimbg = (a) ->
	dim(a, COL_BACKGROUND)


class drawstate
	constructor: (@dr, state) ->
		@tilesize = 40
		@border = @tilesize/2
		@ARROW_HALFSZ = 7 * @tilesize / 32
		@n = state.n
		@dragging = @dx = @dy = 0

	# return coordinate of tile center from index
	cell_center: (cx, cy) ->
		[x, y] = @cell_coord(cx, cy)
		[x + @tilesize / 2, y + @tilesize / 2]
		
	# return coordinate of upper left corner
	cell_coord: (x, y) ->
		[x * @tilesize + @border, y * @tilesize + @border]

	# return cell index for coordinate
	cell_at: (x, y) ->
		[
			0|((x - @border + @tilesize) / @tilesize) - 1
			0|((y - @border + @tilesize) / @tilesize) - 1
		]

	# cx, cy are top-left corner. sz is the 'radius' of the arrow.
	# ang is in radians, clockwise from 0 == straight up.
	draw_arrow: (cx, cy, sz, ang, cfill) ->
		@dr.save()
		@dr.translate cx, cy
		@dr.rotate ang
		xdx3 = (sz * (1.0/3 + 1) + 0.5) - sz
		xdy3 = 0.5
		xdx = sz + 0.5
		xdy = 0.5
		ydx = -xdy
		ydy = xdx
		@dr.beginPath()
		@dr.moveTo -ydx, -ydy
		@dr.lineTo xdx, xdy
		@dr.lineTo xdx3, xdy3
		@dr.lineTo xdx3 + ydx, xdy3 + ydy
		@dr.lineTo -xdx3 + ydx, -xdy3 + ydy
		@dr.lineTo -xdx3, -xdy3
		@dr.lineTo -xdx, -xdy
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

	tile_redraw: (tx, ty, dir, dirp, num, f) ->
		cb = @tilesize / 16
		empty = false
		if num == 0 and not (f & F_ARROW_POINT) and not (f & F_ARROW_INPOINT)
			empty = true
			# We don't display text in empty cells: typically these are
			# signified by num=0. However, in some cases a cell could
			# have had the number 0 assigned to it if the user made an
			# error (e.g. tried to connect a chain of length 5 to the
			# immutable number 4) so we _do_ display the 0 if the cell
			# has a link in or a link out.
		# Calculate colours.
		setcol =
			if empty
				COL_BACKGROUND
			else
				set = 0|(num / (@n + 1))
				if num <= 0 or set == 0
					'#fff'
				else
					set_color(set)

		arrowcol =
			if f & F_DRAG_SRC
				COL_DRAG_ORIGIN
			else if f & F_DIM
				dim(COL_ARROW, setcol)
			else if f & F_ARROW_POINT
				mid(COL_ARROW, setcol)
			else 
				COL_ARROW
		textcol =
			if (f & F_ERROR) and not (f & F_IMMUTABLE)
				COL_ERROR
			else
				_textcol = if f & F_IMMUTABLE then COL_NUMBER_SET else COL_NUMBER
				if f & F_DIM
					dim(_textcol, setcol)
				else if ((f & F_ARROW_POINT) or num == @n) and ((f & F_ARROW_INPOINT) or num == 1)
					mid(_textcol, setcol)
				else
					_textcol
		sarrowcol = if f & F_DIM then dim(COL_ARROW, setcol) else COL_ARROW
		# Clear tile background
		@dr.fillStyle = if f & F_DIM then dimbg(setcol) else setcol
		@dr.fillRect(tx, ty, @tilesize, @tilesize)
		# Draw large (outwards-pointing) arrow.
		asz = @ARROW_HALFSZ # 'radius' of arrow/star.
		acx = tx + @tilesize/2 + asz # centre x
		acy = ty + @tilesize/2 + asz # centre y
		if num == @n and (f & F_IMMUTABLE)
			@draw_star(acx, acy, asz, 5, arrowcol)
		else
			ang = 2.0 * Math.PI * dir / 8.0
			@draw_arrow(acx, acy, asz, ang, arrowcol)
		if f & F_CUR
			@dr.beginPath()
			s = asz + 1
			b = s / 2
			for i in [0 .. 3]
				@dr.save()
				@dr.translate acx, acy
				@dr.rotate i * Math.PI / 2
				@dr.moveTo s, s - b
				@dr.lineTo s, s
				@dr.lineTo s - b, s
				@dr.restore()
			@dr.strokeStyle = COL_CURSOR
			@dr.stroke()
		# Draw dot iff this tile requires a predecessor and doesn't have one.
		acx = tx + @tilesize/2 - asz
		acy = ty + @tilesize/2 + asz
		if not (f & F_ARROW_INPOINT) and num != 1
			@dr.beginPath()
			@dr.arc acx, acy, asz / 4, 0, 2 * Math.PI, false
			@dr.fillStyle = sarrowcol
			@dr.fill()
		# Draw text (number or set).
		if not empty
			set = if num <= 0 then 0 else 0|(num / (@n + 1))
			buf = ''
			if set == 0 or num <= 0
				buf = "#{num}"
			else
				while set > 0
					set--
					buf += ALPHABET[0|(set % ALPHABET.length)]
					set = 0|(set / 26)
				n = 0|(num % (@n + 1))
				if n != 0
					buf += "+#{n}"
			@dr.save()
			@dr.font = "#{@tilesize/3}px sans-serif"
			@dr.fillStyle = textcol
			@dr.fillText(buf, tx + cb, ty + @tilesize * 0.4)
			@dr.restore()
		@dr.strokeStyle = COL_GRID
		@dr.strokeRect(tx, ty, @tilesize, @tilesize)
		null

	draw_drag_indicator: (state, ui, validdrag) ->
		w = state.w
		acol = COL_ARROW
		[fx, fy] = @cell_at(ui.dx, ui.dy)
		if validdrag
			# If we could move here, lock the arrow to the appropriate direction.
			dir = if ui.drag_is_from then state.dirs[ui.sy*w+ui.sx] else state.dirs[fy*w+fx]
			ang = (2.0 * Math.PI * dir) / 8.0 # similar to calculation in draw_arrow_dir.
		else
			# Draw an arrow pointing away from/towards the origin cell.
			[ox, oy] = @cell_center(ui.sx, ui.sy)
			xdiff = Math.abs(ox - ui.dx)
			ydiff = Math.abs(oy - ui.dy)
			ang =
				if xdiff == 0
					if oy > ui.dy then 0 else Math.PI
				else if ydiff == 0
					if ox > ui.dx then 3 * Math.PI / 2 else Math.PI / 2
				else
					if ui.dx > ox and ui.dy < oy
						tana = xdiff / ydiff
						offset = 0
					else if ui.dx > ox and ui.dy > oy
						tana = ydiff / xdiff
						offset = Math.PI / 2
					else if ui.dx < ox and ui.dy > oy
						tana = xdiff / ydiff
						offset = Math.PI
					else
						tana = ydiff / xdiff
						offset = 3 * Math.PI / 2
					Math.atan(tana) + offset
			if not ui.drag_is_from
				ang += Math.PI # poto origin, not away from.
		@draw_arrow(ui.dx, ui.dy, @ARROW_HALFSZ, ang, acol)
		null

	game_redraw: (state, ui) ->
		w = state.w
		postdrop = null
		# If an in-progress drag would make a valid move if finished, we
		# reflect that move in the board display. We let interpret_move do
		# most of the heavy lifting for us: we have to copy the game_ui so
		# as not to stomp on the real UI's drag state.
		if ui.dragging
			uicopy = ui.clone()
			movestr = uicopy.interpret_move(state, this, ui.dx, ui.dy, LEFT_RELEASE)
			if movestr
				state = postdrop = state.execute_move(movestr)
		aw = @tilesize * state.w
		ah = @tilesize * state.h
		@dr.fillStyle = COL_BACKGROUND
		@dr.fillRect(0, 0, aw + 2 * @border, ah + 2 * @border)
		@dr.strokeStyle = COL_GRID
		@dr.strokeRect(@border - 1, @border - 1, aw + 2, ah + 2)
		for x in [0 .. state.w - 1]
			for y in [0 .. state.h - 1]
				i = y*w + x
				f = 0
				dirp = -1
				if ui.cshow and x == ui.cx and y == ui.cy
					f |= F_CUR
				if ui.dragging
					if x == ui.sx and y == ui.sy
						f |= F_DRAG_SRC
					else if ui.drag_is_from
						if not state.ispointing(ui.sx, ui.sy, x, y)
							f |= F_DIM
					else if not state.ispointing(x, y, ui.sx, ui.sy)
						f |= F_DIM
				if state.impossible or state.nums[i] < 0 or state.flags[i] & FLAG_ERROR
					f |= F_ERROR
				if state.flags[i] & FLAG_IMMUTABLE
					f |= F_IMMUTABLE
				if state.next[i] != -1
					f |= F_ARROW_POINT
				if state.prev[i] != -1
					# Currently the direction here is from our square _back_
					# to its previous. We could change this to give the opposite
					# sense to the direction.
					f |= F_ARROW_INPOINT
					dirp = whichdir(x, y, 0|(state.prev[i] % w), 0|(state.prev[i] / w))
				@tile_redraw(@border + x * @tilesize, @border + y * @tilesize, state.dirs[i], dirp, state.nums[i], f)
		if ui.dragging
			@dragging = true
			@dx = ui.dx - @tilesize/2
			@dy = ui.dy - @tilesize/2
			@draw_drag_indicator(state, ui, postdrop?)




window.onload = ->
	params = new game_params(6, 6, true)
	for i in [0 .. 50]
		state = [new_game(params)]
	ui = new game_ui()


	canvas = document.createElement 'canvas'
	document.body.appendChild canvas
	canvas.width = 300
	canvas.height = 300
	ctx = canvas.getContext '2d'
	ds = new drawstate(ctx, state[0])

	ds.game_redraw(state[0], ui)

	make_move = (button, x, y) ->
		mov = ui.interpret_move(state[0], ds, x, y, button)
		if mov
			new_state = state[0].execute_move(mov)
			state.unshift(new_state)
		ds.game_redraw(state[0], ui)


	window.onkeydown = (event) ->
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
				if state.length > 1
					state.shift()
					ds.game_redraw(state[0], ui)
					event.preventDefault()

	canvas.oncontextmenu = (event) ->
		event.stopImmediatePropagation()
		event.preventDefault()

	mouse_is_down = false
	canvas.onmousedown = (event) ->
		mouse_is_down = true
		event.stopImmediatePropagation()
		event.preventDefault()
		x = event.clientX
		y = event.clientY
		switch event.button
			when 0
				make_move(LEFT_BUTTON, x, y)
			when 1
				make_move(MIDDLE_BUTTON, x, y)
			when 2
				make_move(RIGHT_BUTTON, x, y)
		
	canvas.onmouseup = (event) ->
		mouse_is_down = false
		event.stopImmediatePropagation()
		event.preventDefault()
		x = event.clientX
		y = event.clientY
		switch event.button
			when 0
				make_move(LEFT_RELEASE, x, y)
			when 1
				make_move(MIDDLE_RELEASE, x, y)
			when 2
				make_move(RIGHT_RELEASE, x, y)

	canvas.onmousemove = (event) ->
		if mouse_is_down
			event.preventDefault()
			x = event.clientX
			y = event.clientY
			switch event.button
				when 0
					make_move(LEFT_DRAG, x, y)
				when 1
					make_move(MIDDLE_DRAG, x, y)
				when 2
					make_move(RIGHT_DRAG, x, y)

