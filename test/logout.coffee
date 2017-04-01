crypto = require( 'crypto' )

chai = require("chai")
sinon = require("sinon")
sinonChai = require("sinon-chai")
chai.should()
chai.use(sinonChai)

rememberme = require('..')

describe 'rememberme-logout', ->
      
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
    req = 
      get: sinon.stub().withArgs('X-Remember-Me').returns('{"user": "user 1", "token": "token 1"}');
    req.get
    res = {}
    rememberme( configs ).logout req, res, sessionUser, () ->
      configs.deleteToken.should.have.been.called
      configs.deleteToken.should.have.been.calledWith( {id:"1"}, crypto.createHash('md5').update("token 1").digest('hex') )
      done()