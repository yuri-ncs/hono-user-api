#Objection your Honor!

Data validation library for node and the browser.

When doing web development, you spend a lot of time with data validation. It's
a very boring and repetitive task. `honor` is a data validation library which
aims at making it much simpler.

This library is written with CoffeeScript so the examples below are written in
CoffeeScript as well. You can use http://js2coffee.org/ to translate the
examples if you're allergic to it. My sincere apologies to the hardcore
Javascript purists out there.


#Schema

First of all, let's create our base object. You do this by simply requiring
`honor`.


    Honor = require 'honor'
    
This is our base, root object. We can start to define some field types in
there. For instance, let us defined a 'label' field,

    Honor.define 'label',
      trim: true     # trim leading and trailing edges
      required: true # non null, not undefined, not empty string
      maxlen: 50

An 'email' field,

    Honor.define 'email',
      trim: true
      required: true
      maxlen: 50
      email: true

And a 'password' field.

    Honor.define 'password',
      trim: true
      required: true
      maxlen: 50
      minlen: 6
      not_like: /\s/
      default: -> String(Math.random()) # yeap... cool huh?


> **note about _not**...
>
> Any test can be prefixed with "not_", which tests for the
> reverse. So while the "null" test, which returns true if a value is null,
> might seem pretty useless, you can use the "not_null" check, for instance.
  
Now that we have a few field types sorted out, let us create our first schema.
We'll use the classical "User" example. You create new types by calling
extend(). extend() works by doing a deep copy of the parent object, so be sure
to define all the fields, checks, etc. you want shared with your children
objects **before** calling extend()

    User = Honor.extend
      label: Honor.field 'label'
      email: Honor.field 'email'
      password: Honor.field 'password', minlen: 8 # override...
      
# Let's validate something!

    newUser =
      label: "JM Hiver",
      email: " jhiver@gmail.com", some: "junk"
      
    User.validate newUser, (err, usr) ->
      if err
        console.error JSON.stringify { error: err }, null, 2
      else
        console.log JSON.stringify { result: usr }, null, 2
    
Let's see what this outputs:

    {
      "result": {
      "label": "JM Hiver",
        "email": "jhiver@gmail.com",
        "password": "0.15217827167361975"
      }
    }

Hey, not bad! We got our object back, the password field was auto-generated (okay, the password function isn't great, I'll let the reader come up with a better one as an exercise...), the email value was trimmed nicely (noticed the leading whitespace?) and the junk field was removed / cleaned up.

Pretty cool huh?

Now let's see what happens if we pass an invalid object, say

    newUser =
      label: " ",
      email: " jhiver.foo.bar",
      password: 'secrt',
      some: "junk"

Output:

    {
      "error": {
        "label": {
          "required": true
        },
        "email": {
          "email": true
        },
        "password": {
          "minlen": true
        }
      }
    }

# Tests you get for free

`honor` comes with a bunch of pre-written tests, so you don't have to do it
again. Here's the list, in their order or execution.

! order of execution is important !

* **trim**: not really a "test". if the value is a string, it will remove
leading and trailing whitespace, e.g. `password: { trim: true }`

* **default**: again, not really a test. If the value is undefined, replace it
with some other value. Oh and actually, that value can be a function. And
yes, that function can even be asynchronous... see more about that below.

* **coerce**: Forces the type to be a certain value. Current supported types:
'string', 'number', 'boolean', 'moment'. `"password": { "coerce": "string" }`

* **defined**: Will succeed only if the value is not undefined. `"password": {
"defined": true }`

* **null**: Will succeed only if the value is null. `"password": { "null": true
}`

* **required**: true - succeeds if the value is not undefined, not null, and
not an empty string.

* **uuid**: true - succeeds if the value looks like an UUID

* **moment**: true - succeeds if the value is a parseable moment value, see
momentjs library for this awesome date manipulation library.

* **email**: true - succeeds if the value looks like an email

* **integer**: true - succeeds if the value looks like an integer number

* **boolean**: true - succeeds if the value looks like a "boolean". This is
done by casting the value to a string. If the value looks like on|yes|true|1,
then the value is replaced with true and the test succeeds. If the value
looks like off|no|false|0, it's replaced with false. For any other value, the
test fails because the value doesn't look like a yes/no value.

* **hex**: true - succeeds if the value looks like a hexadecimal integer.

* **float**: true - succeeds if the value looks like a float value.

* **like**: regex - succeeds if the String(value) matches the supplied regex.

* **ipv4**: true - succeeds if the value looks like an IPv4 address.

* **host**: true - succeeds if the value looks like a server address,
optionally with a port, i.e. my.server:8080

* **phone**: true - succeeds if the value looks like an e.164 phone number.
i.e. a succession of digits, which can be preceeded with a + sign.

* **url**: true - succeeds if the value looks like an URL.

* **sip**: true - succeeds if the value looks like a SIP address.

* **maxlen**: (length) - succeeds if the value .length attribute is less or
equals than (length)

* **minlen**: (length) - succeeds if the value .length attribute is more or
equals than (length)

* **maxval**: (number) - succeeds if the value is less or equals than (number)

* **minval**: (number) - succeeds if the value is more or equals than (number)

* **equals**: (otherValue) - succeeds if the value is the same as (otherValue)

* **in**: [ value1, value2... ] - succeeds if the value if the same as any of
the values supplied in the array.

* **starts**: (subString) - succeeds if the value starts with (subString)

* **schema**: (schema) - succeeds if the value is an object that matches a sub
schema. Useful for constructing nested schema validation.

* **array_of**: (schema) - succeeds if the value is an array, each object in
the array matching the specified sub schema. Useful for constructing nested
schema validation.


# Writing your own tests

    Honor = require 'honor'
    Honor.check 'mycheck', (c) ->
      ... do stuff with 'c' ...
      return true | false

Here, the 'c' argument if your *context object*. It contains the following
attributes:

* **c.checkValue** - the value of the check. When you write: { "minlen": 25 },
  then 25 is the check value.

* **c.modelValue** - the actual attribute value of the model which is being
  checked against. This is the value that we actually want to validate! Also
  take note that if you used a function in the schema, then c.modelValue is the
  result of that function.

* **c.model** - a reference to the model we are validating. This is not a copy,
  so yes, your checks can alter the model!

* **c.modelAttribute** - the name of the attribute of the model which is being
  checked against.

* **c.honor** - a reference the the honor object that's running the check. In
  the example above, that would be the 'User' object.

# Example:

Let's write a 'young' test, which can be applied to any "moment" type fields,
that measures wether the date is "young" by a factor of certain years, i.e. we
want to be able to write something like:

    Youngster = Honor.extend
      name: Honor.field 'label'
      dob:
        required: true
        moment: true
        young: 25

Let's get down to business and write our test, shall we?

    # adds a 'young' check to  Youngster. I suppose we could also
    # have added it to 'Honor', but then we would have had to
    # to it **before** extending the object with extend().
    Youngster.check 'young', (c) ->
      
      # first get the check value, i.e. if our check looked
      # like young: 25 then the check value would be 25.
      checkValue = Number(c.checkValue)
      if String(checkValue) is 'NaN'
        throw Error "invalid schema: not a number"
      
      # if the model value is not moment, the test should succeed.
      # these things should be checked by other checks, such as
      # required: true and moment: true for instance
      return true unless c.modelValue
      modelValue = moment(c.modelValue)
      return true if not modelValue.isValid()
      
      # the person is deemed 'young'...
      # if he was born AFTER than "checkValue"
      # (in our example, 25...) years ago.
      dateOfBirth = modelValue.valueOf()
      yearsAgo = moment().subtract(checkValue, 'years').valueOf()
      return dateOfBirth > yearsAgo

# Test order is important!

Internally, tests are stored in an array. This is important, because some
checks always need to be run before others. For example, required: true needs
to be run very early, since if a required value isn't present, it's pretty
pointless to be running the other tests.

By default, when you call `Honor.check 'checkName', checkFunction`, the test
will be pushed at the end of the list, unless it replaces another test with the
same name.

You can choose to run the test after or before a certain test however. To do
this, use:

    # let us move 'mycheck' just before the 'email' check
    Honor.moveBefore 'email', 'mycheck'

And of course its counter part function:

    # will you guess what this does?
    Honor.moveAfter 'email', 'mycheck'
  
  
# Asynchronous operations

Sometimes you may want to perform a check against an asynchronous resource,
such as disk, networks, or database. `honor` has you covered!

The only trick is that `honor` needs a way to distinguish between asynchronous
and synchronous functions. If your function returns `Infinity`, then
`honor` will consider it to be asynchronous.

Let's write a test to make sure a URL actually exists.

    request = require 'request'
    Honor = Honor.Create()
    Honor.check 'urlexists', (c, callback) ->

      # if the check value is not true, then we are done
      # and should return true
      unless c.checkValue
        callback null, c.model
        return Infinity
      
      # if the model value is undefined or null,
      # the test should succeed.
      # we can use another test such as "required" to make
      # sure the value is mandatory.
      if c.modelValue is undefined or c.modelValue is null
        callback null, c.model
        return Infinity
      
      modelValue = String c.modelValue
      
      # return check result!
      request modelValue, (error, response, body) ->
        if error
          callback error, null
          return
        
        if not String(response.statusCode).match /^2/
          callback "didn't get 2XX", null
          return
          
        # yes, you must return the model
        # which you may have changed
        return callback null, c.model
     
     return Infinity

Note that not only your checks can work asynchronously, but also your check
values! For instance:

    getNetworkTime = (callback) ->
      # code here...
  
    Timestamp = Honor.extend
      time:
        required: true
      default: (c, callback) ->
        getNetworkTime callback
        return Infinity
  

# Global consistency checks

Let's say we define a user object.

    User = Honor.extend
      label: Honor.field 'label'
      email: Honor.field 'email'
      password: Honor.field 'password'

And then we define another schema for the sign up page.

    Signup = User.extend
      password_verify: required: true
    
And we want to make sure that password equals password_verify. Let's add a constraint!

    Signup.constraint 'same_passwords', (c) ->
      return c.model.password is c.model.password_verify

It is important to note that constraint checks are performed ONLY if all the
"regular" checks went through without errors.
 
Further more, constraints can also be used async-style, which is useful for
database checks.

    dbWrapper = <some_object...>
    Signup.constraint 'email_unique', (c, callback) ->
      filter = email: c.model.email
      dbWrapper.findOne filter, (err, res) ->
        return callback err, null if err
        callback null, c.model
      return Infinity
  
Note that constraints do not run in any particular order. If the error
constraint above fails, error object will contain:

  "constraint": { "email_unique": true }


# Wrapping it up...

That's pretty much it! To summarize:

* Instantiate the root `honor` object by importing the module:
  `Honor = require 'honor'`

* Define some fields if you plan to share field definitions across your schemas
  `Honor.field 'foo', coerce: 'string', trim: true`

* Add your custom tests, which can be synchronous or asynchronous, using Honor.check().

* Define your own schemas using Honor.extend(). Remember this makes a deep copy
  of the object, so you can fiddle with the new object internals as much as you
  like without breaking anything on your other objects.
  `MyModel = Honor.extend <newSchema>`

* Add some constraints to your newly created schema.

* Have fun!


  

