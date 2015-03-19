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
    # The name of the cookie used to store the rememberme info. Defaults to 'rememberme'.
    cookieName : 'rememberme'
    
    # How log should the user be remembered. Defaults to 90 days.
    maxAge: 90 * 24 * 60 * 60 * 1000
    
    checkAuthenticated: ( req ) ->
      # Return true if session is already authenticated
      return req.session? && req.session?.user?
    
    # cookieUser: The user data persisted in cookie. Could be an id or a complex id that will be serialized with JSON.stringify.
    # cb ( err, userRememberMeTokens[], sessionUser ):
    #   err: Error loading user. This will end to request but keep the cookie intact. If you want to clear the cookie (because the user is not found for example), pass null in `userTokens` and `sessionUser`.
    #   userRememberMeTokens: The list of rememberme tokens associated with the user
    #   sessionUser: The user (typically the user id) to save in session. Will be passed back to setUserInSession
    loadUser: ( cookieUser, cb ) ->
      # Should load the session user (from DB) based on user info stored in cookie.
      return
    
    # Will be called with sessionUser passed to loadUser's cb sessionUser when the rememember me token was validated.
    # req: the express Request object.
    # sessionUser: the user loaded by loadUser. Typically the user id.
    setUserInSession: ( req, sessionUser ) ->
      # Should store user information in session. This can then be used in checkAuthenticated.
      req.session.user = sessionUser
      
    # Called when a token is invalidated
    # sessionUser: the user loaded by loadUser. Typically the user id.
    # token: the token to delete
    # cb (err)
    deleteToken: ( sessionUser, token, cb ) ->
      # Should remove the token from persistence store
      return
    
    # Called when an attack is suspected
    # sessionUser: the user loaded by loadUser. Typically the user id.
    # cb (err)
    deleteAllTokens: ( sessionUser, cb ) ->
      # Should remove all tokens from persistence store
      return
  
    # sessionUser: the user loaded by loadUser. Typically the user id.
    # newToken: the newly generated token that should be added to persistence store
    # cb (err)
    saveNewToken: ( sessionUser, newToken, cb ) ->
      return
      
  configs = _.merge defaults, configs  
    
  # Will return the new token in res cookie and the call cb
  generateRememberMeToken = ( sessionUser, currentToken, cookieUser, res, cb ) ->
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
        configs.saveNewToken sessionUser, crypto.createHash('md5').update(newToken).digest('hex'), ( err ) ->
          cb err, newToken
  
    ], ( err, newToken ) ->
      return cb( err ) if err?
  
      # Return the new token in cookie
      res.cookie( configs.cookieName, {user: cookieUser, token: newToken}, {maxAge: configs.maxAge, httpOnly: true} );
      cb null
  
  
  exports = {}
  
  #
  # Should be called after successfull login AND the remember me option was set.
  # Will add a cookie to the response so you must write response only in the callback.
  #
  exports.login = ( sessionUser, cookieUser, res, cb ) ->
    generateRememberMeToken sessionUser, null, cookieUser, res, cb
  
  #
  # Should be called when the user logout.
  # Remove the remember me token from cookie.
  #
  exports.logout = ( req, res, sessionUser, cb ) ->
    # Delete the received token from the list of "remember me" token for that user
    currentToken = req.cookies[configs.cookieName]?.token
    res.clearCookie( configs.cookieName );
    if currentToken?
      configs.deleteToken sessionUser, crypto.createHash('md5').update(currentToken).digest('hex'), cb
    else
      cb null
      
  exports.middleware = (req, res, next) ->
    return next() if configs.checkAuthenticated( req )
    
    # Check is we received rememberme cookie
    remembermeCookie = req.cookies[configs.cookieName]
    return next() unless remembermeCookie?.user? && remembermeCookie?.token?
    
    cookieUser = remembermeCookie.user
    
    async.waterfall [
      ( cb ) ->
        configs.loadUser cookieUser, cb
        
      , (userRememberMeTokens, sessionUser, cb ) ->
        if sessionUser? && userRememberMeTokens?
          if _.contains userRememberMeTokens, crypto.createHash('md5').update(remembermeCookie.token).digest('hex')
            
            # Set the user in session and handle the request
            configs.setUserInSession( req, sessionUser )
            
            # Generate a new remembre me token
            generateRememberMeToken sessionUser, crypto.createHash('md5').update(remembermeCookie.token).digest('hex'), cookieUser, res, cb
  
          else
            # Wipe all user.rememberMeToken token in case this is an attack
            res.clearCookie( configs.cookieName );
            configs.deleteAllTokens sessionUser, cb
        else
          res.clearCookie( configs.cookieName );
          cb null
        
    ], ( err ) ->
      next( err )
  
  return exports 