mocha   = require 'mocha'
chai    = require 'chai'
assert  = chai.assert
Honor   = require '../lib/honor.coffee'
_ = require 'underscore'

describe 'basic_tests', ->

  it 'minval', (done) ->
    schema = Honor.extend
      field:
        required: false
        integer: true
        minval: 10
    schema.validate { field: 9 }, (err, res) ->
      if err
        return done()
      else
        return done "integer passes where it should not"

  it 'minval #2', (done) ->
    schema = Honor.extend
      field:
        required: false
        integer: true
        minval: 10
    schema.validate { field: 11 }, (err, res) ->
      if err
        return done "integer passes where it should not"
      else
        return done()

  it 'maxval', (done) ->
    schema = Honor.extend
      field:
        required: false
        integer: true
        maxval: 10
    schema.validate { field: 11 }, (err, res) ->
      if err
        return done()
      else
        return done "integer passes where it should not"

  it 'maxval #2', (done) ->
    schema = Honor.extend
      field:
        required: false
        integer: true
        maxval: 10
    schema.validate { field: 9 }, (err, res) ->
      if err
        return done "integer passes where it should not"
      else
        return done()


  it 'integer', (done) ->
    schema = Honor.extend
      field:
        required: false
        integer: true
    schema.validate { field: "foo" }, (err, res) ->
      if err
        return done()
      else
        return done "integer passes where it should not"

  it 'trim', (done) ->
    schema = Honor.extend field: trim: true
    schema.validate { field: " foo " }, (err, res) ->
      if res.field is 'foo'
        return done()
      else
        return done "incorrect value '#{res.field}'"

  it 'default', (done) ->
    schema = Honor.extend field: default : 'foo'
    schema.validate {}, (err, res) ->
      if res.field is 'foo'
        return done()
      else
        return done "incorrect value '#{res.field}'"

  it 'default (function)', (done) ->
    schema = Honor.extend field: default : -> 'foo'
    schema.validate {}, (err, res) ->
      if res.field is 'foo'
        return done()
      else
        return done "incorrect value '#{res.field}'"

  it 'default (async function)', (done) ->
    asyncOp = (callback) ->
      setTimeout ->
        callback null, "foo"
      , 10

    asyncFunction = (c, callback) ->
      asyncOp callback
      return Infinity

    schema = Honor.extend field: default : asyncFunction
    schema.validate {}, (err, res) ->
      if res.field is 'foo'
        return done()
      else
        return done "incorrect value '#{res.field}'"

  it 'coerce', (done) ->
    schema = Honor.extend field: coerce : 'string'
    schema.validate {}, (err, res) ->
      if res.field is 'undefined'
        return done()
      else
        return done "incorrect value '#{res.field}'"

  it 'coerce (function)', (done) ->
    schema = Honor.extend field: coerce : -> 'string'
    schema.validate {}, (err, res) ->
      if res.field is 'undefined'
        return done()
      else
        return done "incorrect value '#{res.field}'"

  it 'coerce (async function)', (done) ->
    asyncOp = (callback) ->
      setTimeout ->
        callback null, "string"
      , 10

    asyncFunction = (c, callback) ->
      asyncOp callback
      return Infinity

    schema = Honor.extend field: coerce : asyncFunction
    schema.validate {}, (err, res) ->
      if res.field is 'undefined'
        return done()
      else
        return done "incorrect value '#{res.field}'"