validUrl = require 'valid-url'
moment   = require 'moment'
deepcopy = require 'deepcopy'
_        = require 'underscore'


# this function validates a list of objects against a schema, and returns
# the response through callback.
SchemaListValidate = (list, schema, newModel, newErrors, callback) ->

  # if the list is empty, then we're done processing our list.
  # if we don't have any errors, return the model
  # otherwise returns the errors
  if list.length is 0
    if _.isEmpty newErrors
      return callback null, newModel
    else
      return callback newErrors, null

  # fetch the next item in the list
  nextItem = list.shift()

  # if the next item is undefined or null, raise an error
  if nextItem.val is undefined
    newErrors[nextItem.key].undefined = true
    return SchemaListValidate list, schema, newModel, newErrors, callback
  if nextItem.val is null
    newErrors[nextItem.key].undefined = true
    return SchemaListValidate list, schema, newModel, newErrors, callback

  # raise an error is the next item isn't an object as we're currently
  # too dumb to take care of these scenarios it seems...
  unless _.isObject nextItem.val
    newErrors[nextItem.key].type = true
    return SchemaListValidate list, schema, newModel, newErrors, callback

  # validate the object against the schema.
  # updates errors and model, and move to the next item using recursion.
  schema.validate nextItem.val, (err) ->
    if err
      newErrors[nextItem.key] = err
    else
      newModel.push nextItem.val
    SchemaListValidate list, schema, newModel, newErrors, callback


# makes synchronous tests asynchronous, unless they already are.
# this means that in effect, you can write tests / checks in either
# a synchronous or asynchronous manner.
MakeAsync = (aFunction, functionArguments..., callback) ->
  result = aFunction functionArguments..., callback
  callback null, result unless result is Infinity


# returns the result of check.checkValue.
# if check.checkValue is a function, invokes it.
valOrEval = (check, callback) ->
  if _.isFunction check.checkValue
    MakeAsync check.checkValue, check, callback
  else
    return callback null, check.checkValue


Create = (aSchema) ->
  self = {}
  self.schema = if aSchema then aSchema else {}
  self.checklist = []
  self.constraints = {}


  # Field(s) management.
  self._field = {}


  # TEST ME, god damn it!
  self.errorsToList = (err, prefix) ->
    prefix or= []
    result = []
    if _.isObject err
      _.each err, (val, key) ->
        subList = self.errorsToList val, [prefix..., key]
        _.each subList, (item) -> result.push item
    else if err
      return [ prefix.join '_' ]
    else
      return []

  self.define = (fieldName, miniSchema) -> self._field[fieldName] = miniSchema


  self.constraint = (aName, aFunction) ->
    self.constraints[aName] = aFunction


  self.field = (fieldName, miniSchema) ->
    result = self._field[fieldName] or {}
    if miniSchema
      _.each miniSchema, (v,k) -> result[k] = v
    return result


  # Used to extend to other types.
  self.extend = (aSchema) ->
    copy = Create deepcopy self.schema
    copy.checklist = deepcopy self.checklist
    if aSchema
      _.each aSchema, (v,k) -> copy.schema[k] = v
    return copy


  # appends a check at the end of the check list
  self.check = (checkName, checkFunction) ->
    newChecklist = []
    wasReplaced = false
    _.each self.checklist, (checkObject) ->
      if checkObject.checkName is checkName
        newChecklist.push
          checkName: checkName
          checkFunction: checkFunction
        wasReplaced = true
      else
        newChecklist.push checkObject
    if not wasReplaced
      newChecklist.push
        checkName: checkName
        checkFunction: checkFunction
    self.checklist = newChecklist


  self.deleteCheck = (checkName) ->
    checkToDelete = null
    newChecklist = []
    _.each self.checklist, (checkObject) ->
      if checkObject.checkName is checkName
        checkToDelete = checkObject
      else
        newChecklist.push checkObject
    if checkToDelete
      self.checklist = newChecklist
      return checkToDelete
    else
      return null


  # moves a check before another one
  self.moveIt = (checkName, checkNameToMove, cb) ->
    deletedCheck = self.deleteCheck checkNameToMove
    throw Error "check to move wasn't found" unless deletedCheck

    newChecklist   = []
    found = false
    _.each self.checklist, (checkObject) -> found = true if cb checkObject, newChecklist, deletedCheck
    throw Error "check name was not found" unless found
    self.checklist = newChecklist


  # moves a check before another one
  self.moveBefore = (checkName, checkNameToMove) ->
    self.moveIt checkName, checkNameToMove, (checkObject, newChecklist, deletedCheck) ->
      found = false
      if checkObject.checkName is checkName
        newChecklist.push deletedCheck
        found = true
      newChecklist.push checkObject
      return found


  # moves a check after another one
  self.moveAfter = (checkName, checkNameToMove) ->
    self.moveIt checkName, checkNameToMove, (checkObject, newChecklist, deletedCheck) ->
      found = false
      newChecklist.push checkObject
      if checkObject.checkName is checkName
        newChecklist.push deletedCheck
        found = true
      return found


  # validates the model. Async style callback.
  # this function crosses the checklist with
  # the schema to create a list of checks to run.
  #
  # it then passes this checks list to self.validateChecklist()
  # which runs them serially.
  self.validate = (model, callback) ->
    _.each model, (v,k) ->
      delete model[k] unless self.schema[k]

    checklist = []
    _.each self.checklist, (check) ->
      _.each self.schema, (attributeField, modelAttribute) ->
        _.each attributeField, (checkValue, checkName) ->
          checkNameInitial = checkName
          reverseCheck = false
          if checkName.match /^not_/
            reverseCheck = true
            checkName = checkName.replace /^not_/, ''
          return unless check.checkName is checkName
          check = _.clone check
          check.model = model
          check.modelAttribute = modelAttribute
          check.modelValue = model[modelAttribute]
          check.checkValue = checkValue
          check.reverseCheck = reverseCheck
          check.honor = self
          check.checkNameInitial = checkNameInitial
          checklist.push check

    _.each self.constraints, (checkFunction, checkName) ->
      checklist.push 
        checkName: checkName
        checkFunction: checkFunction
        checkNameInitial: checkName
        model: model
        honor: self
        modelAttribute: 'constraint'

    self.validateChecklist checklist, {}, (err) ->
      return callback err, null if err
      return callback null, model


  # runs the checks in checklist serially, and when done
  # with all the checks, calls callback()
  self.validateChecklist = (checklist, newError, callback) ->
    if checklist.length is 0
      if _.isEmpty newError
        return callback()
      else
        return callback newError

    # fetch the next check in the list...
    nextCheck = checklist.shift()
    nextCheck.modelValue = nextCheck.model[nextCheck.modelAttribute]

    # if we already have an error for this attribute, skip it
    if newError[nextCheck.modelAttribute]
      return self.validateChecklist checklist, newError, callback

    # if nextCheck.checkValue is a function, we need to invoke it to
    # replace it with its output value. Otherwise, we just need to use
    # the value. This is what "valOrEval" does.
    valOrEval nextCheck, (error, checkValue) ->

      # if we have an error, then we couldn't eval the nextCheck.checkValue function.
      # let's return an error and jump to the next check.
      if error
        newError[nextCheck.modelAttribute] = {}
        newError[nextCheck.modelAttribute][nextCheck.checkNameInitial] = error
        return self.validateChecklist checklist, newError, callback

      # otherwise, let's replace the function with its return value, and then we
      # can invoke nextCheck.checkFunction passing it the check object, and expecting
      # an optional error.
      else
        nextCheck.checkValue = checkValue
        MakeAsync nextCheck.checkFunction, nextCheck, (error, result) ->

          if error
            newError[nextCheck.modelAttribute] = {}
            newError[nextCheck.modelAttribute][nextCheck.checkNameInitial] = error
            return self.validateChecklist checklist, newError, callback

          result = not result if nextCheck.reverseCheck
          unless result
            newError[nextCheck.modelAttribute] = {}
            newError[nextCheck.modelAttribute][nextCheck.checkNameInitial] = true
            return self.validateChecklist checklist, newError, callback

          nextCheck.modelValue = nextCheck.model[nextCheck.modelAttribute]
          return self.validateChecklist checklist, newError, callback

  self.blindJudge = -> 313

  return self


# We're done with our constructor, so now let's create our root object.
Honor = Create()


# trim: <value>
# ----------------------------------------------------------------------------
# Gets rid of whitespace leading and trailing edges on string values.
Honor.check 'trim', (c) ->

  # if not trim: true, then skip
  return true unless c.checkValue

  # if the model value is not a string,
  # there is nothing to trim
  return true if typeof(c.modelValue) isnt 'string'

  # now trim the model value and return
  value = c.modelValue
  value = value.replace /^\s+/, ''
  value = value.replace /\s+$/, ''
  c.model[c.modelAttribute] = value
  return true


# default: <value>
# --------------------------- fit e-------------------------------------------------
# Sets the field to <value> unless it's already defined
Honor.check 'default', (c) ->

  # if the model value is not undefined or null, then we're done.
  return true if c.modelValue isnt undefined and c.modelValue isnt null

  # replace the model attribute with the check value, and return
  c.model[c.modelAttribute] = c.checkValue
  return true


# coerce: <value>
# ----------------------------------------------------------------------------
# Coerces the field to a given object / type
Honor.check 'coerce', (c) ->
  switch c.checkValue
    when 'string'  then c.model[c.modelAttribute] = String c.model[c.modelAttribute]
    when 'number'  then c.model[c.modelAttribute] = Number c.model[c.modelAttribute]
    when 'boolean' then c.model[c.modelAttribute] = Boolean c.model[c.modelAttribute]
    when 'moment'  then c.model[c.modelAttribute] = moment c.model[c.modelAttribute]
  return true


# defined: true|false
# ----------------------------------------------------------------------------
# is this field defined?
Honor.check 'defined', (c) ->

  # if not defined: true, then skip
  return true unless c.checkValue

  return c.modelValue isnt undefined


# null: true|false
# ----------------------------------------------------------------------------
# is this field null?
Honor.check 'null', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  return c.modelValue is null


# required: true|false
# ----------------------------------------------------------------------------
# is this field required, i.e. not undefined, not null, and not empty?
Honor.check 'required', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # 'required' means not undefined, not null, and not empty
  return false if c.modelValue is undefined
  return false if c.modelValue is null
  return false if String(c.modelValue) is ''
  return true


# uuid: true|false
# ----------------------------------------------------------------------------
# must this field look like an uuid?
Honor.check 'uuid', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  return String(c.modelValue).match /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i


# moment: true|false
# ----------------------------------------------------------------------------
# must this field look like a moment?
Honor.check 'moment', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  return moment(c.modelValue).isValid()


# email: true|false
# ----------------------------------------------------------------------------
# must this field look like an email?
Honor.check 'email', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true if c.modelValue is undefined
  return true if c.modelValue is null

  return String(c.modelValue).match /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/


# integer: true|false
# ----------------------------------------------------------------------------
# must this field look like an integer?
Honor.check 'integer', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true if c.modelValue is undefined
  return true if c.modelValue is null
  return String(c.modelValue).match /^[-]?\d+$/


# boolean: true|false
# ----------------------------------------------------------------------------
# must this field look like an boolean?
Honor.check 'boolean', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  # does it "look like" true?
  if String(c.modelValue).match /^(on|yes|true|1)$/i
    c.model[c.modelAttribute] = true
    return true

  # does it "look like" false?
  else if /^(off|no|false|0)$/i
    c.model[c.modelAttribute] = false
    c.modelValue = false
    return true

  # else it's probably nonsense, fail the test.
  else
    return false


# hex: true|false
# ----------------------------------------------------------------------------
# must this field look like an hex positive integer?
Honor.check 'hex', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  return String(c.modelValue).match /^[a-fA-F0-9]+$/
  

# float: true|false
# ----------------------------------------------------------------------------
# must this field look like an float number?
Honor.check 'float', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  return String(c.modelValue).match /^[-]?[0-9]*[\.]?[0-9]+$/


# like: <regex>
# ----------------------------------------------------------------------------
# must this field look like <regex>?
Honor.check 'like', (c) ->

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  # if the modelValue is undefined, well
  return String(c.modelValue).match c.checkValue


# ipv4: true|false
# ----------------------------------------------------------------------------
# must this field look like an ipv4?
Honor.check 'ipv4', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  return String(c.modelValue).match /^((([01]?[0-9]{1,2})|(2[0-4][0-9])|(25[0-5]))[.]){3}(([0-1]?[0-9]{1,2})|(2[0-4][0-9])|(25[0-5]))$/


# host: true|false
# ----------------------------------------------------------------------------
# must this field look like a host?
Honor.check 'host', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  return String(c.modelValue).match /^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?$/


# phone: true|false
# ----------------------------------------------------------------------------
# must this field look like a phone number?
Honor.check 'phone', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  return String(c.modelValue).match /^\+?\d+$/


# url: true|false
# ----------------------------------------------------------------------------
# must this field look like a url?
Honor.check 'url', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  return validUrl.isUri String(c.modelValue)


# sip: true|false
# ----------------------------------------------------------------------------
# must this field look like a sip address?
Honor.check 'sip', (c) ->

  # if not null: true, then skip
  return true unless c.checkValue

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  return String(c.modelValue).match String(value).match(/^\+?(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))(:\d+)?$/)


# maxlen: <value>
# ----------------------------------------------------------------------------
# Make sure this field length doesn't exceed <value> chars
Honor.check 'maxlen', (c) ->

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  # if c.checkValue doesn't look like a number
  # then we should fail the test.
  len = Number c.checkValue
  return false if String(len) is 'NaN'

  # try to make the comparison, return false if that fails.
  retVal = false
  try
    retVal = c.modelValue.length <= len
  catch err
    return false

  return retVal


# minlen: <value>
# ----------------------------------------------------------------------------
# Make sure this field length is at least <value> chars
Honor.check 'minlen', (c) ->

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  # if c.checkValue doesn't look like a number
  # then we should fail the test.
  len = Number c.checkValue
  return false if String(len) is 'NaN'

  # try to make the comparison, return false if that fails.
  retVal = false
  try
    retVal = c.modelValue.length <= len
  catch err
    return false

  return retVal


# maxval: <value>
# ----------------------------------------------------------------------------
# Make sure this field doesn't exceed <value> chars
Honor.check 'maxval', (c) ->

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true if c.modelValue is undefined
  return true if c.modelValue is null

  # if c.checkValue doesn't look like a number
  # then we should fail the test.
  checkValue = Number c.checkValue
  return false if String(checkValue) is 'NaN'

  # if c.modelValue doesn't look like a number
  # then we should fail the test.
  modelValue = Number c.modelValue
  return false if String(modelValue) is 'NaN'

  return modelValue <= checkValue


# minval: <value>
# ----------------------------------------------------------------------------
# Make sure this field doesn't exceed <value> chars
Honor.check 'minval', (c) ->

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true if c.modelValue is undefined
  return true if c.modelValue is null

  # if c.checkValue doesn't look like a number
  # then we should fail the test.
  checkValue = Number c.checkValue
  return false if String(checkValue) is 'NaN'

  # if c.modelValue doesn't look like a number
  # then we should fail the test.
  modelValue = Number c.modelValue
  return false if String(modelValue) is 'NaN'

  return modelValue >= checkValue


# equals: <value>
# ----------------------------------------------------------------------------
# Isn't that self-explanatory?
Honor.check 'equals', (c) ->
  return c.modelValue is c.checkValue


# in: ['val1', 'val2', 'val3']
# ----------------------------------------------------------------------------
# Make sure this field doesn't exceed <value> chars
Honor.check 'in', (c) ->
  return true unless c.checkValue
  if _.isArray c.checkValue
    for checkVal in c.checkValue
      if checkVal is c.modelValue
        return true
  return false


# starts: <value>
# ----------------------------------------------------------------------------
# checks if this field starts with <value>
Honor.check 'starts', (c) ->

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  # on the other hand if the check value is undefined or null
  # then the test is complete non sense, and we should fail
  return false unless c.checkValue is undefined
  return false unless c.checkValue is null

  checkVal = String c.checkValue
  return String(c.modelValue).indexOf(checkVal) is 0


# contains: <value>
# ----------------------------------------------------------------------------
# checks if this field contains <value>
Honor.check 'contains', (c) ->

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  # on the other hand if the check value is undefined or null
  # then the test is complete non sense, and we should fail
  return false unless c.checkValue is undefined
  return false unless c.checkValue is null

  checkVal = String c.checkValue
  return String(c.modelValue).indexOf(checkVal) >= 0


# schema: <value>
# ----------------------------------------------------------------------------
# checks if this field implements the given schema
Honor.check 'schema', (c, callback) ->

  # if the model value is undefined or null
  # we should succeed the test. defined: true and not_null: true
  # are meant to be testing for this.
  return true unless c.modelValue is undefined
  return true unless c.modelValue is null

  # Is the object that we're being passed one of our objects?
  # Attempt to figure out if it implements a very improbable
  # function returning an even more improbable value.
  checkValue = c.checkValue
  return false unless _.isObject checkValue
  return false unless checkValue.blindJudge
  return false unless checkValue.blindJudge() is 313

  return true unless c.checkValue
  schema = c.checkValue
  model  = c.modelValue
  schema.validate model, (err) ->
    if err
      return callback err, null
    else
      return callback null, model
  return Infinity


# schema: <value>
# ----------------------------------------------------------------------------
# checks if this field implements the given schema
Honor.check 'array_of', (c, callback) ->
  return true unless c.checkValue
  schema = c.checkValue
  model  = c.modelValue

  list = []
  _.each model, (val, key) -> list.push val: val, key: key
  SchemaListValidate list, schema, [], {}, callback
  return Infinity


module.exports = Honor
