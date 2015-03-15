chai = require("chai")
sinon = require("sinon")
sinonChai = require("sinon-chai")
crypto = require( 'crypto' )
chai.should()
chai.use(sinonChai)

rememberme = require('..')

randomBuffer = new Buffer(32)

describe 'rememberme-login', ->
  it 'should return cookie on login', ( done ) ->
    configs = 
      checkAuthenticated: sinon.spy()
      loadUser: sinon.spy()
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy()
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy ( sessionUser, newToken, cb ) ->
        cb null

    sessionUser = {id:"1"}
    cookieUser = "user 1"
    res = {
      cookie: sinon.spy()
    }
    
    sinon.stub(crypto, "randomBytes", (size, cb) ->
      cb null, randomBuffer
    )
    
    rememberme( configs ).login sessionUser, cookieUser, res, () ->
      configs.deleteToken.should.have.not.been.called
      configs.saveNewToken.should.have.been.calledOnce
      configs.saveNewToken.should.have.been.calledWith( {id:"1"} )
      res.cookie.should.have.been.calledOnce
      res.cookie.should.have.been.calledWith( "rememberme", {user:"user 1", token:randomBuffer.toString( 'hex' )}, {maxAge: 90 * 24 * 60 * 60 * 1000, httpOnly: true} )
      crypto.randomBytes.restore()
      done()
      
  it 'should return cookie with configured name and max age', ( done ) ->
    configs = 
      maxAge: 1
      cookieName: 'customname' 
      checkAuthenticated: sinon.spy()
      loadUser: sinon.spy()
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy()
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy ( sessionUser, newToken, cb ) ->
        cb null

    sessionUser = {id:"1"}
    cookieUser = "user 1"
    res = {
      cookie: sinon.spy()
    }
    
    sinon.stub(crypto, "randomBytes", (size, cb) ->
      cb null, randomBuffer
    )
    
    rememberme( configs ).login sessionUser, cookieUser, res, () ->
      newToken = configs.saveNewToken.args[0][1]
      res.cookie.should.have.been.calledOnce
      res.cookie.should.have.been.calledWith( "customname", {user:"user 1", token:randomBuffer.toString( 'hex' )}, {maxAge: 1, httpOnly: true} )
      crypto.randomBytes.restore()
      done()