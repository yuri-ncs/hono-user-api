Honor = require '../lib/honor.coffee'

Schema = Honor.extend
	date_start:
		required: true
		moment: true
	date_end:
		required: true
		moment: true
	trunk:
		required: true
	country:
		required: true
	source:
		remove_empty: true
	destination:
		remove_empty: true
	duration_min:
		required: true
		integer: true
		minval: 0
		maxval: 9999
	duration_max:
		required: true
		integer: true
		minval: 0
		maxval: 9999
	cost_min:
		required: true
		integer: true
		minval: 0
		maxval: 9999
	cost_max:
		required: true
		integer: true
		minval: 0
		maxval: 9999

Schema.check 'remove_empty', (c) ->
	return true unless c.checkValue
	if c.modelValue is undefined
		delete c.model[c.modelAttribute]
		return true
	if c.modelValue is null
		delete c.model[c.modelAttribute]
		return true
	if c.modelValue is ""
		delete c.model[c.modelAttribute]
		return true

	return true

Schema.moveBefore 'required', 'remove_empty'

Schema.constraint 'duration', (c) -> c.model.duration_min <= c.model.duration_max
Schema.constraint 'cost', (c) -> c.model.cost_min <= c.model.cost_max

object =
	cost_max: 9999
	cost_min: 0
	country: "all"
	date_end: "2014-12-03"
	date_start: "2014-12-03"
	duration_max: 0
	duration_min: 9999
	trunk: "all"

Schema.validate object, (err, res) ->
	console.log "err", err
	console.log "res", res
module.exports = Schema