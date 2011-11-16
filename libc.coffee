assert = (ex) ->
	if not ex
		throw 'assertion failed'

memset = (array, value, length) ->
	for i in [0 .. length - 1]
		array[i] = value

memcpy = (to, from, length) ->
	for i in [0 .. length - 1]
		to[i] = from[i]

snewn = (length, type = null) ->
	if type?
		new type() for index in [0 .. length - 1]
	else
		0 for index in [0 .. length - 1]

qsort = (array, length, cmp) ->
	array.sort(cmp)

Math.random_int = (limit) ->
	@floor(@random() * limit)

random_upto = (random_state, limit) ->
	Math.random_int(limit)

Array::shuffle = ->
	for i in [@length - 1 .. 1] by -1
		j = Math.random_int(i + 1)
		[this[j], this[i]] = [this[i], this[j]]
	null

Array::fill = (value) ->
	for _v, index in this
		this[index] = value
	null

