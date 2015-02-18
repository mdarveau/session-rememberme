chai = require("chai")
sinon = require("sinon")
sinonChai = require("sinon-chai")
chai.should()
chai.use(sinonChai)

rememberme = require('..')

describe 'rememberme-logout', ->
  it 'should do nothing if cookie not set', ( done ) ->
    configs = 
      checkAuthenticated: sinon.spy()
      loadUser: sinon.spy()
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy ( sessionUser, currentToken, cb ) ->
        cb null
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy()

    sessionUser = {id:"1"}
    req = {cookies:[]}
    res = {
      cookie: sinon.spy()
      clearCookie: sinon.spy()
    }
    rememberme( configs ).logout req, res, sessionUser, () ->
      configs.deleteToken.should.have.not.been.called
      res.clearCookie.should.have.been.called
      done()
 
  it 'should do nothing if no token in cookie', ( done ) ->
    configs = 
      checkAuthenticated: sinon.spy()
      loadUser: sinon.spy()
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy ( sessionUser, currentToken, cb ) ->
        cb null
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy()

    sessionUser = {id:"1"}
    req = {cookies:[]}
    req.cookies['customname'] = 
      user: "user 1"
    res = {
      cookie: sinon.spy()
      clearCookie: sinon.spy()
    }
    rememberme( configs ).logout req, res, sessionUser, () ->
      configs.deleteToken.should.have.not.been.called
      res.clearCookie.should.have.been.called
      done()
      
  it 'should remove tokem and clear cookie', ( done ) ->
    configs = 
      checkAuthenticated: sinon.spy()
      loadUser: sinon.spy()
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy ( sessionUser, currentToken, cb ) ->
        cb null
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy()

    sessionUser = {id:"1"}
    req = {cookies:[]}
    req.cookies['rememberme'] = 
      user: "user 1"
      token: "token 1"
    res = {
      cookie: sinon.spy()
      clearCookie: sinon.spy()
    }
    rememberme( configs ).logout req, res, sessionUser, () ->
      res.clearCookie.should.have.been.called
      configs.deleteToken.should.have.been.called
      configs.deleteToken.should.have.been.calledWith( {id:"1"}, "token 1" )
      done()