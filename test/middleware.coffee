chai = require("chai")
sinon = require("sinon")
sinonChai = require("sinon-chai")
chai.should()
chai.use(sinonChai)

rememberme = require('..')

describe 'rememberme-middleware', ->
  it 'should do nothing if authenticated', ( done ) ->
    configs = 
      checkAuthenticated: sinon.stub().returns( true )
      loadUser: sinon.spy()
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy()
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy()

    req = {}
    res = {}
    rememberme( configs ).middleware req, res, () ->
      configs.checkAuthenticated.should.have.been.calledOnce
      configs.checkAuthenticated.should.have.been.calledWith( req )
      configs.loadUser.should.have.not.been.called
      configs.setUserInSession.should.have.not.been.called
      done()

  describe 'cookie-test', ->
    it 'should do nothing if cookie not set', ( done ) ->
      configs = 
        checkAuthenticated: sinon.stub().returns( false )
        loadUser: sinon.spy()
        setUserInSession: sinon.spy()
        deleteToken: sinon.spy()
        deleteAllTokens: sinon.spy()
        saveNewToken: sinon.spy()
  
      req = {cookies:[]}
      res = {}
      rememberme( configs ).middleware req, res, () ->
        configs.loadUser.should.have.not.been.called
        configs.setUserInSession.should.have.not.been.called
        done()
      
    it 'should do nothing if user not set in cookie', ( done ) ->
      configs = 
        checkAuthenticated: sinon.stub().returns( false )
        loadUser: sinon.spy()
        setUserInSession: sinon.spy()
        deleteToken: sinon.spy()
        deleteAllTokens: sinon.spy()
        saveNewToken: sinon.spy()
  
      req = {cookies:[]}
      req.cookies['rememberme'] = 
        dummyValue: "123"
        token: "token"
      res = {}
      rememberme( configs ).middleware req, res, () ->
        configs.loadUser.should.have.not.been.called
        configs.setUserInSession.should.have.not.been.called
        done()
      
    it 'should do nothing if token not set in cookie', ( done ) ->
      configs = 
        checkAuthenticated: sinon.stub().returns( false )
        loadUser: sinon.spy()
        setUserInSession: sinon.spy()
        deleteToken: sinon.spy()
        deleteAllTokens: sinon.spy()
        saveNewToken: sinon.spy()
  
      req = {cookies:[]}
      req.cookies['rememberme'] = 
        dummyValue: "123"
        token: "token"
      res = {}
      rememberme( configs ).middleware req, res, () ->
        configs.loadUser.should.have.not.been.called
        configs.setUserInSession.should.have.not.been.called
        done()
            
  it 'should load user with cookie info', ( done ) ->
    configs = 
      checkAuthenticated: sinon.stub().returns( false )
      loadUser: sinon.spy ( cookieUser, cb ) ->
        done()
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy()
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy()
  
    req = {cookies:[]}
    req.cookies['rememberme'] = 
      user: "user 1"
      token: "token 1"
    res = {}
    rememberme( configs ).middleware req, res, null
    
  it 'should clear cookie when user is not found', ( done ) ->
    configs = 
      checkAuthenticated: sinon.stub().returns( false )
      loadUser: sinon.spy ( cookieUser, cb ) ->
        cb null, [], null
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy()
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy()
  
    req = {cookies:[]}
    req.cookies['rememberme'] = 
      user: "user 1"
      token: "token 1"
    res = {
      clearCookie: sinon.spy()
    }
    rememberme( configs ).middleware req, res, () ->
      res.clearCookie.should.have.been.calledOnce
      res.clearCookie.should.have.been.calledWith( 'rememberme' )
      done()
      
  it 'should clear all tokens when provided token is not found', ( done ) ->
    configs = 
      checkAuthenticated: sinon.stub().returns( false )
      loadUser: sinon.spy ( cookieUser, cb ) ->
        cb null, ['token 2'], {id:"1"}
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy()
      deleteAllTokens: sinon.spy ( user, cb ) ->
        cb null
      saveNewToken: sinon.spy()
  
    req = {cookies:[]}
    req.cookies['rememberme'] = 
      user: "user 1"
      token: "token 1"
    res = {}
    rememberme( configs ).middleware req, res, () ->
      configs.deleteAllTokens.should.have.been.calledOnce
      configs.deleteAllTokens.should.have.been.calledWith( {id:"1"} )
      done()
     
  it 'should set user in session when provided token is found', ( done ) ->
    configs = 
      checkAuthenticated: sinon.stub().returns( false )
      loadUser: sinon.spy ( cookieUser, cb ) ->
        cb null, ['token 1'], {id:"1"}
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy ( sessionUser, currentToken, cb ) ->
        cb null
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy ( sessionUser, newToken, cb ) ->
        cb null
  
    req = {cookies:[]}
    req.cookies['rememberme'] = 
      user: "user 1"
      token: "token 1"
    res = {
      cookie: sinon.spy()
    }
    rememberme( configs ).middleware req, res, () ->
      configs.setUserInSession.should.have.been.calledOnce
      configs.setUserInSession.should.have.been.calledWith( req, {id:"1"} )
      configs.deleteToken.should.have.been.calledOnce
      configs.deleteToken.should.have.been.calledWith( {id:"1"}, "token 1" )
      configs.saveNewToken.should.have.been.calledOnc
      configs.saveNewToken.should.have.been.calledWith( {id:"1"} )
      configs.deleteToken.should.have.been.calledWith( {id:"1"}, "token 1" )
      newToken = configs.saveNewToken.args[0][1]
      res.cookie.should.have.been.calledOnce
      res.cookie.should.have.been.calledWith( "rememberme", {user:"user 1", token:newToken}, {maxAge: 90 * 24 * 60 * 60 * 1000, httpOnly: true} )
      done()
      
  it 'should return cookie with configured name and max age', ( done ) ->
    configs = 
      maxAge: 1
      cookieName: 'customname'
      checkAuthenticated: sinon.stub().returns( false )
      loadUser: sinon.spy ( cookieUser, cb ) ->
        cb null, ['token 1'], {id:"1"}
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy ( sessionUser, currentToken, cb ) ->
        cb null
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy ( sessionUser, newToken, cb ) ->
        cb null
  
    req = {cookies:[]}
    req.cookies['customname'] = 
      user: "user 1"
      token: "token 1"
    res = {
      cookie: sinon.spy()
    }
    rememberme( configs ).middleware req, res, () ->
      newToken = configs.saveNewToken.args[0][1]
      res.cookie.should.have.been.calledOnce
      res.cookie.should.have.been.calledWith( "customname", {user:"user 1", token:newToken}, {maxAge: 1, httpOnly: true} )
      done()