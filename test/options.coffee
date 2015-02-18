chai = require("chai")
sinon = require("sinon")
sinonChai = require("sinon-chai")
chai.should()
chai.use(sinonChai)

rememberme = require('..')

describe 'rememberme-login', ->
  it 'should thow error when loadUser is not defined', ( done ) ->
    configs = {}

    try
      rememberme = sinon.spy( rememberme )
      rememberme( configs )
    catch e
      
    rememberme.should.have.thrown( "loadUser must be defined" )
    done()
      
  it 'should thow error when deleteToken is not defined', ( done ) ->
    configs =
      loadUser: sinon.spy()

    try
      rememberme = sinon.spy( rememberme )
      rememberme( configs )
    catch e
      
    rememberme.should.have.thrown( "deleteToken must be defined" )
    done()
    
  it 'should thow error when deleteAllTokens is not defined', ( done ) ->
    configs = 
      loadUser: sinon.spy()
      deleteToken: sinon.spy()

    try
      rememberme = sinon.spy( rememberme )
      rememberme( configs )
    catch e
      
    rememberme.should.have.thrown( "deleteAllTokens must be defined" )
    done()
    
  it 'should thow error when saveNewToken is not defined', ( done ) ->
    configs = 
      loadUser: sinon.spy()
      deleteToken: sinon.spy()
      deleteAllTokens: sinon.spy()

    try
      rememberme = sinon.spy( rememberme )
      rememberme( configs )
    catch e
      
    rememberme.should.have.thrown( "saveNewToken must be defined" )
    done()