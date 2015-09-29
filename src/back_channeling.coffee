{Robot,Adapter,TextMessage,User} = require 'hubot'
EventEmitter = require('events').EventEmitter

HTTP = require('http')
EDN = require('jsedn')
WebSocket = require('ws')

class BackChanneling extends Adapter

  send: (envelope, strings...) ->
    @robot.logger.info "Send"
    @bot.comment strings.join('\n')

  reply: (envelope, strings...) ->
    @robot.logger.info "Reply"

  run: ->
    logger = @robot.logger
    code = process.env.HUBOT_BACK_CHANNELING_CODE
    
    options =
      port: process.env.HUBOT_BACK_CHANNELING_PORT or= 3009
      host: process.env.HUBOT_BACK_CHANNELING_HOST or= "localhost"
      thread_id: process.env.HUBOT_BACK_CHANNELING_THREAD_ID
      
    bot = new BackChannelingStreaming options, @robot
    @bot = bot

    bot.on 'message', (user, body, id) =>
      return if user.name is @robot.name
      @robot.receive new TextMessage(user, body, id)
      
    bot.authenticate code, (token) ->
      bot.watch()
      bot.listen token

    @emit "connected"


exports.use = (robot) ->
  new BackChanneling robot

class BackChannelingStreaming extends EventEmitter

  constructor: (options, @robot) ->
    @host = options.host
    @thread_id = options.thread_id
    @port  = options.port

  listen:(token) =>
    setupWebSocket = () =>
      @robot.logger.info "BackChanneling connect... ws://#{@host}:#{@port}/ws/?token=#{token}"
      ws = new WebSocket "ws://#{@host}:#{@port}/ws/?token=#{token}"
      
      ws.on 'open', () =>
        @robot.logger.info "BackChanneling connected."

      ws.on 'error', (event) =>
        @robot.logger.error "BackChanneling error: #{event}"

      ws.on 'close', (code, message) =>
        @robot.logger.info "BackChanneling disconnected: code=#{code}, message=#{message}"

      ws.on 'message', (data, flags) =>
        @robot.logger.debug "ws message=#{data}"
        message = try EDN.parse data catch e then data or {}
        if message.at(0) == EDN.kw(":notify")
          user = @robot.brain.userForId message.at(1).at(EDN.kw(":comment/posted-by")).at(EDN.kw(":user/name"))
          @emit 'message',
            user,
            message.at(1).at(EDN.kw(":comment/content")),
            message.at(1).at(EDN.kw(":comment/no"))
          
    setupWebSocket()

  comment: (text) ->
    logger = @robot.logger
    @request "POST", "/api/thread/#{@thread_id}/comments", { "comment/content": text }, (data) =>
      logger.info "Posted a comment: #{text}"
    
  watch: () ->
    logger = @robot.logger
    @request "PUT", "/api/thread/#{@thread_id}", { "add-watcher": {} }, (data) =>
      logger.info "Watched the #{@thread_id} thread."

  request: (method, path, body, callback) ->
    logger = @robot.logger
    options =
      "host": @host
      "port": @port
      "path": path
      "method": method
      "headers":
        "Content-Type": "application/json"
        "Accept": "application/json"
        "Authorization": "Token #{@token}"

    req = HTTP.request options, (res) =>
      res.setEncoding "utf8"
      res.on 'data', (chunk) =>
        if res.statusCode == 200 or res.statusCode == 201 or res.statusCode == 204
          if callback
            callback(JSON.parse chunk)
        else
          logger.error "Failed to request #{path}. reason: #{chunk}"

    req.on "error", (err) ->
      logger.error "Failed to comment. reason: #{err}"

    if body
      req.write(JSON.stringify body)

    logger.debug "request #{method} #{path} #{@token}"
    req.end()
      
  authenticate: (code, callback) ->
    logger = @robot.logger
    options =
      "host": @host
      "port": @port
      "path": "/api/token"
      "method": "POST"
      "headers":
        "Content-Type": "application/x-www-form-urlencoded"
        "Accept": "application/json" 

    req = HTTP.request options, (res) =>
      res.setEncoding "utf8"
      res.on 'data', (chunk) =>
        if res.statusCode == 201
          @token = JSON.parse(chunk)["access-token"]
          callback(@token)
        else
          logger.error "Failed to connect. reason: #{chunk}"

    req.on 'error', (err) ->
      logger.error "Failed to connect. reason: #{err}"
      
    req.write("code=#{code}")
    req.end()

    
