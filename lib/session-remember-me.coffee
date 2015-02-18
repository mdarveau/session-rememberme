_ = require("lodash")
bcrypt = require( 'bcrypt' )
crypto = require( 'crypto' )
async = require( 'async' )

module.exports = ( configs ) ->
  throw "loadUser must be defined" unless configs?.loadUser?
  throw "deleteToken must be defined" unless configs?.deleteToken?
  throw "deleteAllTokens must be defined" unless configs?.deleteAllTokens?
  throw "saveNewToken must be defined" unless configs?.saveNewToken?
  
  defaults = 
    cookieName : 'rememberme'
    maxAge: 90 * 24 * 60 * 60 * 1000
    
    # Return true if session is already authenticated
    checkAuthenticated: ( req ) ->
      return req.session? && req.session?.user?
    
    # Should load the session user (from DB) based on cookie user.
    # cookieUser: The user data persisted in cookie. Could be an id or a complex id that will be serialized with JSON.stringify.
    # cb: ( userRememberMeTokens[], sessionUser )
    #   err: Error loading user. This will end to request but keep the cookie intact. If you want to clear the cookie (because the user is not found for example), pass null in `userTokens` and `sessionUser`.
    #   userRememberMeTokens: The list of rememberme tokens associated with the user
    #   sessionUser: The user to save in session. Will be passed back to setUserInSession
    loadUser: ( cookieUser, cb ) ->
      return
    
    # Will be called with sessionUser passed to loadUser's cb sessionUser when the rememember me token was validated.
    setUserInSession: ( req, sessionUser ) ->
      req.session.user = sessionUser
      
    deleteToken: ( sessionUser, token, cb ) ->
      return
    
    deleteAllTokens: ( sessionUser, cb ) ->
      return
  
    saveNewToken: ( sessionUser, newToken, cb ) ->
      return
      
  configs = _.merge defaults, configs  
    
  # Will return the new token in res cookie and the call cb
  generateRememberMeToken = ( req, sessionUser, currentToken, cookieUser, res, cb ) ->
    async.waterfall [
      ( cb ) ->
        # Delete current token
        if currentToken?
          configs.deleteToken sessionUser, currentToken, cb
        else
          cb( null )
    , ( cb ) ->
        
      # Generate a new token
      crypto.randomBytes 32, cb
  
    , ( newTokenBuffer, cb ) ->
        newToken = newTokenBuffer.toString( 'hex' )
    
        # Persist the new token
        configs.saveNewToken sessionUser, newToken, ( err ) ->
          cb err, newToken
  
    ], ( err, newToken ) ->
      return cb( err ) if err?
  
      # Return the new token in cookie
      console.log "#{req.method} #{req.path}: Returning cookie: #{newToken}"
      res.cookie( configs.cookieName, {user: cookieUser, token: newToken}, {maxAge: configs.maxAge, httpOnly: true} );
      cb null
  
  
  exports = {}
  
  #
  # Should be called after successfull login AND the remember me option was set.
  # Will add a cookie to the response so you must write response only in the callback.
  #
  exports.login = ( req, sessionUser, cookieUser, res, cb ) ->
    generateRememberMeToken req, sessionUser, null, cookieUser, res, cb
  
  #
  # Should be called when the user logout.
  # Remove the remember me token from cookie.
  #
  exports.logout = ( req, res, sessionUser, cb ) ->
    # Delete the received token from the list of "remember me" token for that user
    currentToken = req.cookies[configs.cookieName]?.token
    res.clearCookie( configs.cookieName );
    if currentToken?
      configs.deleteToken sessionUser, currentToken, cb
    else
      cb null
      
  exports.middleware = (req, res, next) ->
    return next() if configs.checkAuthenticated( req )
    
    # Check is we received rememberme cookie
    remembermeCookie = req.cookies[configs.cookieName]
    console.log "#{req.method} #{req.path}: remembermeCookie: #{JSON.stringify(remembermeCookie)}"
    return next() unless remembermeCookie?.user? && remembermeCookie?.token?
    
    cookieUser = remembermeCookie.user
    
    async.waterfall [
      ( cb ) ->
        configs.loadUser cookieUser, cb
        
      , (userRememberMeTokens, sessionUser, cb ) ->
        if sessionUser? && userRememberMeTokens?
          console.log "#{req.method} #{req.path}: Loaded user with tokens: [#{userRememberMeTokens}], looking for #{remembermeCookie.token}"
          if _.contains userRememberMeTokens, remembermeCookie.token
            console.log "#{req.method} #{req.path}: Token validated"
            
            # Set the user in session and handle the request
            configs.setUserInSession( req, sessionUser )
            
            # Generate a new remembre me token
            generateRememberMeToken req, sessionUser, remembermeCookie?.token, cookieUser, res, cb
  
          else
            # Wipe all user.rememberMeToken token in case this is an attack
            console.log "#{req.method} #{req.path}: Invalid token, clearing cookie"
            res.clearCookie( configs.cookieName );
            configs.deleteAllTokens sessionUser, cb
        else
          console.log "#{req.method} #{req.path}: User not found, clearing cookie"
          res.clearCookie( configs.cookieName );
          cb null
        
    ], ( err ) ->
      console.log "#{req.method} #{req.path}: Remember me error: #{JSON.stringify(err)}" if err 
      next( err )
  
  return exports 