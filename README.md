# session-rememberme

This express/connect middleware adds "remember me" feature with the best practices as described in [this post](http://stackoverflow.com/questions/549/the-definitive-guide-to-form-based-website-authentication#477579).


## Installation 

npm: `npm install session-rememberme`

## Usage

Note: all examples are in [coffeescript](http://coffeescript.org/)

    options =
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

    rememberme = require("session-rememberme")( options )
    
To use as [express middleware](http://expressjs.com/guide/using-middleware.html):

    app = express()
    app.use( rememberme.middleware )
    
When a user successfully login and the "remember me" option was selected:

    rememberme.login user.id, user.id, res, ( err ) ->
        # Continue request handling
        
When a user logout:

    rememberme.logout req, res, user.id, ( err ) ->
        # Continue request handling
        
## Sails example:

Create `api/services/RememberMeService.coffee`:

    # cookieUser is always User.id
    
    options = 
      checkAuthenticated: ( req ) ->
        return req.session? && req.session?.user?
      
      loadUser: ( cookieUser, cb ) ->
        User.findOneById( cookieUser ).exec ( err, user ) ->
          cb null, user.rememberMeTokens, user.id
      
      # Will be called with sessionUser passed to loadUser's cb sessionUser when the rememember me token was validated.
      setUserInSession: ( req, sessionUser ) ->
        req.session.user = sessionUser
        
      deleteToken: ( sessionUser, token, cb ) ->
        User.findOneById( sessionUser ).exec ( err, user ) ->
          return cb err if err
          user.rememberMeTokens = _.without sessionUser.rememberMeTokens, token
          user.save ( err, user ) ->
            cb err
      
      deleteAllTokens: ( sessionUser, cb ) ->
        User.findOneById( sessionUser ).exec ( err, user ) ->
          return cb err if err
          user.rememberMeTokens = []
          user.save ( err, user ) ->
            cb err
    
      saveNewToken: ( sessionUser, newToken, cb ) ->
        User.findOneById( sessionUser ).exec ( err, user ) ->
          return cb err if err
          user.rememberMeTokens ?= []
          user.rememberMeTokens.push newToken
          user.save ( err, user ) ->
            cb err
    
    _.merge exports, require("session-rememberme")( options )
    
Assuming `User` defined as:

    module.exports =
    
      attributes:
        ...
    
        rememberMeTokens:
          type: 'array'
        
        ...
        
Edit `config/http.coffee`:

    order: [
        ...
        "session"
        "rememberme"
        ...
      ]
    
      rememberme: (req, res, next) ->
        RememberMeService.middleware(req, res, next)
        
In your controller, after successful login:

    RememberMeService.login user.id, user.id, res, ( err ) ->

In your controller, after successful logout:
        
    RememberMeService.logout req, res, user.id, ( err ) ->
    
