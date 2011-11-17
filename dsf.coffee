# dsf.c: some functions to handle a disjoint set forest,
# which is a data structure useful in any solver which has to
# worry about avoiding closed loops.

class DisjointSetForest
	constructor: (size) ->
		@dsf = (6 for i in [1 .. size])
		# Bottom bit of each element of this array stores whether that
		# element is opposite to its parent, which starts off as
		# false. Second bit of each element stores whether that element
		# is the root of its tree or not.  If it's not the root, the
		# remaining 30 bits are the parent, otherwise the remaining 30
		# bits are the number of elements in the tree.

	clone: ->
		r = new DisjointSetForest(@size)
		for value, index in @dsf
			r.dsf[index] = value
		r

	canonify: (index) ->
		@extended_canonify(index, null)[0]

	merge: (v1, v2) ->
		@extended_merge(v1, v2, false)
		null

	size: (index) ->
		@dsf[@canonify(index)] >> 2

	extended_canonify: (index) ->
		start_index = index
		inverse = 0
		# Find the index of the canonical element of the 'equivalence class' of
		# which start_index is a member, and figure out whether start_index is the
		# same as or inverse to that.
		while (@dsf[index] & 2) == 0
			inverse ^= (@dsf[index] & 1)
			index = @dsf[index] >> 2
		canonical_index = index
		inverse_return = inverse
		# Update every member of this 'equivalence class' to point directly at the
		# canonical member.
		index = start_index
		while index != canonical_index
			nextindex = @dsf[index] >> 2
			nextinverse = inverse ^ (@dsf[index] & 1)
			@dsf[index] = (canonical_index << 2) | inverse
			inverse = nextinverse
			index = nextindex
		[index, inverse_return]

	extended_merge: (v1, v2, inverse) ->
		[v1, i1] = @extended_canonify(v1)
		inverse ^= i1
		[v2, i2] = @extended_canonify(v2)
		inverse ^= i2
		if v1 != v2
			# We always make the smaller of v1 and v2 the new canonical
			# element. This ensures that the canonical element of any
			# class in this structure is always the first element in
			# it. 'Keen' depends critically on this property.
			#
			# (Jonas Koelker previously had this code choosing which
			# way round to connect the trees by examining the sizes of
			# the classes being merged, so that the root of the
			# larger-sized class became the new root. This gives better
			# asymptotic performance, but I've changed it to do it this
			# way because I like having a deterministic canonical
			# element.)
			if v1 > v2
				[v1, v2] = [v2, v1]
			@dsf[v1] += (@dsf[v2] >> 2) << 2
			@dsf[v2] = (v1 << 2) | !!inverse
		[v2, i2] = @extended_canonify(v2)
		null
