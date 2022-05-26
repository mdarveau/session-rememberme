Promise = require('bluebird')
chai = require("chai")
sinon = require("sinon")
sinonChai = require("sinon-chai")
crypto = require( 'crypto' )
chai.should()
chai.use(sinonChai)

rememberme = require('..')

randomBuffer = new Buffer.alloc(32)

describe 'rememberme-login', ->
  it 'should return cookie on login', ->
    configs = 
      checkAuthenticated: sinon.spy()
      loadUser: sinon.spy()
      setUserInSession: sinon.spy()
      deleteToken: sinon.spy()
      deleteAllTokens: sinon.spy()
      saveNewToken: sinon.spy ( sessionUser, newToken ) -> Promise.resolve()

    sessionUser = {id:"1"}
    cookieUser = "user 1"
    res = {
      set: sinon.spy()
    }
    
    sinon.stub(crypto, "randomBytes").callsFake -> randomBuffer

    await rememberme( configs ).login sessionUser, cookieUser, res

    configs.deleteToken.should.have.not.been.called
    configs.saveNewToken.should.have.been.calledOnce
    configs.saveNewToken.should.have.been.calledWith( {id:"1"} )
    res.set.should.have.been.calledOnce
    console.log "#{JSON.stringify(res.set.args, null, '  ')}"
    res.set.should.have.been.calledWith( "X-Remember-Me", JSON.stringify({user:"user 1", token:randomBuffer.toString( 'hex' )}) )
    crypto.randomBytes.restore()