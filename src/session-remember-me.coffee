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
    # How log should the user be remembered. Defaults to 90 days.
    maxAge: 90 * 24 * 60 * 60 * 1000
    
    checkAuthenticated: ( req ) ->
      # Return true if session is already authenticated
      return req.session? && req.session?.user?
    
    # userFromData: The user data persisted in browser. Could be an id or a complex id that will be serialized with JSON.stringify.
    # cb ( err, userRememberMeTokens[], sessionUser ):
    #   err: Error loading user. This will end to request but keep the browser data intact. If you want to clear the browser data (because the user is not found for example), pass null in `userTokens` and `sessionUser`.
    #   userRememberMeTokens: The list of rememberme tokens associated with the user
    #   sessionUser: The user (typically the user id) to save in session. Will be passed back to setUserInSession
    loadUser: ( userFromData, cb ) ->
      # Should load the session user (from DB) based on user info stored in browser.
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
    
  # Will return the new token in http header 'X-Remember-Me' and the call cb
  generateRememberMeToken = ( sessionUser, currentToken, userFromData, res, cb ) ->
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
  
      # Return the new token in 'X-Remember-Me' header
      token = {user: userFromData, token: newToken}
      res.set('X-Remember-Me', JSON.stringify(token));
      cb null
  
  
  exports = {}
  
  #
  # Should be called after successfull login AND the remember me option was set.
  # Will add a header to the response so you must write response only in the callback.
  #
  exports.login = ( sessionUser, userFromData, res, cb ) ->
    generateRememberMeToken sessionUser, null, userFromData, res, cb
  
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
    
    # Try getting it from the headers
    remembermeData = req.get('X-Remember-Me')
    remembermeData = JSON.parse(remembermeData) if remembermeData?
    return next() unless remembermeData?.user? && remembermeData?.token?
    
    userFromData = remembermeData.user
    
    async.waterfall [
      ( cb ) ->
        configs.loadUser userFromData, cb
        
      , (userRememberMeTokens, sessionUser, cb ) ->
        if sessionUser? && userRememberMeTokens?
          if _.contains userRememberMeTokens, crypto.createHash('md5').update(remembermeData.token).digest('hex')
            
            # Set the user in session and handle the request
            configs.setUserInSession( req, sessionUser )
            
            # Generate a new remembre me token
            generateRememberMeToken sessionUser, crypto.createHash('md5').update(remembermeData.token).digest('hex'), userFromData, res, cb
  
          else
            # Wipe all user.rememberMeToken token in case this is an attack
            configs.deleteAllTokens sessionUser, cb
        else
          cb null
        
    ], ( err ) ->
      next( err )
  
  return exports 