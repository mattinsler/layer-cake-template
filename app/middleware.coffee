express = require 'express'

module.exports = (app) ->
  app.use express.logger()
  app.use express.compress()
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser()
  app.use express.session(secret: 'please dont tell')
  
  app.use app.awesomebox.middleware(app.path.public)
  app.use express.static(app.path.public)
  
  app.use app.router
