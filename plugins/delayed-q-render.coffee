q = require 'q'

collect_promises = (obj) ->
  promises = []
  
  Object.keys(obj).forEach (k) ->
    v = obj[k]
    if q.isPromise(v)
      promises.push(v.then (data) ->
        obj[k] = data
      )
  
  promises

delay_render = (app) ->
  (done) ->
    _render = app.express.render
    app.express.render = (name, options, fn) ->
      promises = [].concat([
        collect_promises(options._locals)
        collect_promises(options)
      ]...)
      
      q.all(promises).then => _render.call(@, name, options, fn)
    
    done()

module.exports = (app) ->
  app.sequence('http').insert('delayed-q-render', delay_render(app), after: '*')
