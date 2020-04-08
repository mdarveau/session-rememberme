_ = require("lodash")
bcrypt = require( 'bcrypt' )
crypto = require( 'crypto' )

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
    # return [userRememberMeTokens[], sessionUser]
    #   userRememberMeTokens: The list of rememberme tokens associated with the user
    #   sessionUser: The user (typically the user id) to save in session. Will be passed back to setUserInSession
    loadUser: ( userFromData ) ->
      # Should load the session user (from DB) based on user info stored in browser.
      return

    # Will be called with sessionUser passed to loadUser's sessionUser return value when the rememember me token was validated.
    # req: the express Request object.
    # sessionUser: the user loaded by loadUser. Typically the user id.
    setUserInSession: ( req, sessionUser ) ->
      # Should store user information in session. This can then be used in checkAuthenticated.
      req.session.user = sessionUser

    # Called when a token is invalidated
    # sessionUser: the user loaded by loadUser. Typically the user id.
    # token: the token to delete
    # Return Promise
    deleteToken: ( sessionUser, token ) ->
      # Should remove the token from persistence store
      return

    # Called when an attack is suspected
    # sessionUser: the user loaded by loadUser. Typically the user id.
    # Return Promise
    deleteAllTokens: ( sessionUser ) ->
      # Should remove all tokens from persistence store
      return

    # sessionUser: the user loaded by loadUser. Typically the user id.
    # newToken: the newly generated token that should be added to persistence store
    # Return Promise
    saveNewToken: ( sessionUser, newToken ) ->
      return

  configs = _.merge defaults, configs

  # Will return the new token in http header 'X-Remember-Me'
  generateRememberMeToken = (sessionUser, currentToken, userFromData, res) ->
    # Delete current token
    await configs.deleteToken sessionUser, currentToken if currentToken?

    # Generate a new token
    newToken = crypto.randomBytes(32).toString("hex")

    await configs.saveNewToken sessionUser, crypto.createHash('md5').update(newToken).digest('hex')

    # Return the new token in 'X-Remember-Me' header
    res.set('X-Remember-Me', JSON.stringify({user: userFromData, token: newToken}))

  exports = {}

  #
  # Should be called after successfull login AND the remember me option was set.
  # Will add a header to the response so you must write response only in the callback.
  #
  exports.login = ( sessionUser, userFromData, res ) ->
    await generateRememberMeToken sessionUser, null, userFromData, res

  #
  # Should be called when the user logout.
  # Remove the remember me token from storage.
  #
  exports.logout = ( req, res, sessionUser ) ->
    # Delete the received token from the list of "remember me" token for that user
    remembermeData = req.get('X-Remember-Me')
    if remembermeData?
      remembermeData = JSON.parse(remembermeData)
      await configs.deleteToken sessionUser, crypto.createHash('md5').update(remembermeData.token).digest('hex')

  exports.middleware = (req, res, next) ->
    return next() if configs.checkAuthenticated( req )

    # Try getting it from the headers
    remembermeData = req.get('X-Remember-Me')
    console.log("remembermeData = " + remembermeData)
    remembermeData = JSON.parse(remembermeData) if remembermeData?
    return next() unless remembermeData?.user? && remembermeData?.token?

    userFromData = remembermeData.user

    [userRememberMeTokens, sessionUser] = await configs.loadUser userFromData
    return next() unless sessionUser? && userRememberMeTokens?

    console.log("remember me token #{crypto.createHash('md5').update(remembermeData.token).digest('hex')} #{_.includes userRememberMeTokens, crypto.createHash('md5').update(remembermeData.token).digest('hex') ? 'found' : 'not found'} in #{userRememberMeTokens}")
    if _.includes userRememberMeTokens, crypto.createHash('md5').update(remembermeData.token).digest('hex')
      # Set the user in session and handle the request
      configs.setUserInSession( req, sessionUser )

      # Generate a new remembre me token
      await generateRememberMeToken sessionUser, crypto.createHash('md5').update(remembermeData.token).digest('hex'), userFromData, res

    else
      # Wipe all user.rememberMeToken token in case this is an attack
      await configs.deleteAllTokens sessionUser

    next()

  return exports
