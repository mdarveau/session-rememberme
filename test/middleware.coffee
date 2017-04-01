chai = require("chai")
sinon = require("sinon")
sinonChai = require("sinon-chai")
crypto = require( 'crypto' )
chai.should()
chai.use(sinonChai)

rememberme = require('..')

randomBuffer = new Buffer(32)

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
  
      req = 
        get: sinon.stub().withArgs('X-Remember-Me').returns(null);
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
  
      req = 
        get: sinon.stub().withArgs('X-Remember-Me').returns('{"dummy": "value", "token": "token 1"}');
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
      req = 
        get: sinon.stub().withArgs('X-Remember-Me').returns('{"user": "user 1", "dummy": "value"}');
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
  
    req = 
      get: sinon.stub().withArgs('X-Remember-Me').returns('{"user": "user 1", "token": "token 1"}');
    res = {}
    rememberme( configs ).middleware req, res, null
    
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
  
    req = 
      get: sinon.stub().withArgs('X-Remember-Me').returns('{"user": "user 1", "token": "token 1"}');
    res = {}
    rememberme( configs ).middleware req, res, () ->
      configs.deleteAllTokens.should.have.been.calledOnce
      configs.deleteAllTokens.should.have.been.calledWith( {id:"1"} )
      done()
     
  it 'should set user in session when provided token is found', ( done ) ->
    configs = 
      checkAuthenticated: sinon.stub().returns( false )
      loadUser: sinon.spy ( cookieUser, cb ) ->
        cb null, [crypto.createHash('md5').update('token 1').digest('hex')], {id:"1"}
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy ( sessionUser, currentToken, cb ) ->
        cb null
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy ( sessionUser, newToken, cb ) ->
        cb null
  
    req = 
      get: sinon.stub().withArgs('X-Remember-Me').returns('{"user": "user 1", "token": "token 1"}');
    res = {
      set: sinon.spy()
    }
    
    sinon.stub(crypto, "randomBytes", (size, cb) ->
      cb null, randomBuffer
    )
    
    rememberme( configs ).middleware req, res, () ->
      configs.setUserInSession.should.have.been.calledOnce
      configs.setUserInSession.should.have.been.calledWith( req, {id:"1"} )
      configs.deleteToken.should.have.been.calledOnce
      configs.deleteToken.should.have.been.calledWith( {id:"1"}, crypto.createHash('md5').update("token 1").digest('hex') )
      configs.saveNewToken.should.have.been.calledOnce
      configs.saveNewToken.should.have.been.calledWith( {id:"1"} )
      res.set.should.have.been.calledOnce
      res.set.should.have.been.calledWith( "X-Remember-Me", "{\"user\":\"user 1\",\"token\":\"#{randomBuffer.toString( 'hex' )}\"}" )
      crypto.randomBytes.restore()
      done()