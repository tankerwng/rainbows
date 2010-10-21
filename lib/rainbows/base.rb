# -*- encoding: binary -*-

# base class for \Rainbows! concurrency models, this is currently used by
# ThreadSpawn and ThreadPool models.  Base is also its own
# (non-)concurrency model which is basically Unicorn-with-keepalive, and
# not intended for production use, as keepalive with a pure prefork
# concurrency model is extremely expensive.
module Rainbows::Base

  # :stopdoc:
  include Rainbows::ProcessClient

  # shortcuts...
  G = Rainbows::G

  # this method is called by all current concurrency models
  def init_worker_process(worker) # :nodoc:
    super(worker)
    Rainbows::Response.setup(self.class)
    Rainbows::MaxBody.setup
    G.tmp = worker.tmp

    listeners = Rainbows::HttpServer::LISTENERS
    Rainbows::HttpServer::IO_PURGATORY.concat(listeners)

    # we're don't use the self-pipe mechanism in the Rainbows! worker
    # since we don't defer reopening logs
    Rainbows::HttpServer::SELF_PIPE.each { |x| x.close }.clear
    trap(:USR1) { reopen_worker_logs(worker.nr) }
    trap(:QUIT) { G.quit! }
    [:TERM, :INT].each { |sig| trap(sig) { exit!(0) } } # instant shutdown
    Rainbows::ProcessClient.const_set(:APP, G.server.app)
    logger.info "Rainbows! #@use worker_connections=#@worker_connections"
  end

  def self.included(klass) # :nodoc:
    klass.const_set :LISTENERS, Rainbows::HttpServer::LISTENERS
    klass.const_set :G, Rainbows::G
  end

  # :startdoc:
end
