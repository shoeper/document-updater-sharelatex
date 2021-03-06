sinon = require('sinon')
chai = require('chai')
should = chai.should()
modulePath = "../../../../app/js/DispatchManager.js"
SandboxedModule = require('sandboxed-module')

describe "DispatchManager", ->
	beforeEach ->
		@DispatchManager = SandboxedModule.require modulePath, requires:
			"./UpdateManager" : @UpdateManager = {}
			"logger-sharelatex": @logger = { log: sinon.stub() }
			"settings-sharelatex": @settings =
				redis:
					web: {}
			"redis-sharelatex": @redis = {}
		@callback = sinon.stub()

	describe "each worker", ->
		beforeEach ->
			@client =
				auth: sinon.stub()
			@redis.createClient = sinon.stub().returns @client
			
			@worker = @DispatchManager.createDispatcher()
			
		it "should create a new redis client", ->
			@redis.createClient.called.should.equal true
			
		describe "_waitForUpdateThenDispatchWorker", ->
			beforeEach ->
				@project_id = "project-id-123"
				@doc_id = "doc-id-123"
				@doc_key = "#{@project_id}:#{@doc_id}"
				@client.blpop = sinon.stub().callsArgWith(2, null, ["pending-updates-list", @doc_key])
				@UpdateManager.processOutstandingUpdatesWithLock = sinon.stub().callsArg(2)
				
				@worker._waitForUpdateThenDispatchWorker @callback
				
			it "should call redis with BLPOP", ->
				@client.blpop
					.calledWith("pending-updates-list", 0)
					.should.equal true
					
			it "should call processOutstandingUpdatesWithLock", ->
				@UpdateManager.processOutstandingUpdatesWithLock
					.calledWith(@project_id, @doc_id)
					.should.equal true
					
			it "should call the callback", ->
				@callback.called.should.equal true
				
		describe "run", ->
			it "should call _waitForUpdateThenDispatchWorker until shutting down", (done) ->
				callCount = 0
				@worker._waitForUpdateThenDispatchWorker = (callback = (error) ->) =>
					callCount++
					if callCount == 3
						@settings.shuttingDown = true
					setTimeout () ->
						callback()
					, 10
				sinon.spy @worker, "_waitForUpdateThenDispatchWorker"
				
			
				@worker.run()
				
				setTimeout () =>
					@worker._waitForUpdateThenDispatchWorker.callCount.should.equal 3
					done()
				, 100
					
			
	