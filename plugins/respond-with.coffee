q = require 'q'
util = require 'util'

collect_promises = (obj) ->
  promises = []
  
  return promises unless obj?
  return promises unless typeof obj is 'object'
  
  Object.keys(obj).forEach (k) ->
    v = obj[k]
    if q.isPromise(v)
      promises.push(v.then (data) ->
        obj[k] = data
      )
    else if typeof v is 'object'
      promises.push(collect_promises(v)...)
  
  promises

strip = (obj) ->
  return null unless obj?
  return obj.map(strip) if Array.isArray(obj)
  return obj unless typeof obj is 'object'
  
  res = {}
  proto = obj

  while proto isnt Object.prototype
    for k in Object.getOwnPropertyNames(proto)
      d = Object.getOwnPropertyDescriptor(proto, k)
      res[k] = obj[k] if d.value? and d.enumerable is true and typeof d.value isnt 'function'
    proto = proto.__proto__

  res

transform = (obj, fields) ->
  return strip(obj) unless fields?.length > 0
  
  transform_item = (item) ->
    fields.reduce (o, f) ->
      if typeof f is 'string'
        o[f] = item[f] if item[f]?
      else
        for k, v of f
          if typeof v is 'function'
            try
              o[k] = v(item[k])
            catch err
          else
            o[v] = item[k]
      o
    , {}
  
  is_arr = Array.isArray(obj)
  
  obj = [obj] unless is_arr
  obj = obj.map (o) -> strip(transform_item(o))
  
  if is_arr then obj else obj[0]

add_respond_with = (app) ->
  (done) ->
    app.express.response.respond_with = (obj, fields...) ->
      return @json(404) unless obj?
      if util.isError(obj)
        console.log obj.stack
        return @json(500, error: obj.message)
      
      fields = fields.filter((f) -> f?)
      wrapped = {wrap: obj}
      promises = collect_promises(wrapped)
      q.all(promises).then =>
        return @json(404) unless wrapped.wrap?
        if util.isError(wrapped.wrap)
          console.log wrapped.wrap.stack
          return @json(500, error: wrapped.wrap.message)
        
        if fields.length is 1
          if Array.isArray(fields[0])
            fields = fields[0]
          else if typeof fields[0] is 'function'
            return app.express.response.respond_with.call(@, fields[0](wrapped.wrap))
        
        @json(200, transform(wrapped.wrap, fields))
      
      .catch (err) =>
        console.log err.stack
        @json(500, error: err.message)
  
    done()

module.exports = (app) ->
  app.sequence('http').insert('respond-with', add_respond_with(app), after: '*')
