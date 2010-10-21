# -*- encoding: binary -*-
# :enddoc:
require 'rainbows/fiber/io'

module Rainbows::Fiber::Base

  include Rainbows::Base

  # :stopdoc:
  RD = Rainbows::Fiber::RD
  WR = Rainbows::Fiber::WR
  ZZ = Rainbows::Fiber::ZZ
  # :startdoc:

  # the scheduler method that powers both FiberSpawn and FiberPool
  # concurrency models.  It times out idle clients and attempts to
  # schedules ones that were blocked on I/O.  At most it'll sleep
  # for one second (returned by the schedule_sleepers method) which
  # will cause it.
  def schedule(&block)
    ret = begin
      G.tick
      RD.compact.each { |c| c.f.resume } # attempt to time out idle clients
      t = schedule_sleepers
      Kernel.select(RD.compact.concat(LISTENERS), WR.compact, nil, t) or return
    rescue Errno::EINTR
      retry
    rescue Errno::EBADF, TypeError
      LISTENERS.compact!
      raise
    end or return

    # active writers first, then _all_ readers for keepalive timeout
    ret[1].concat(RD.compact).each { |c| c.f.resume }

    # accept is an expensive syscall, filter out listeners we don't want
    (ret[0] & LISTENERS).each(&block)
  end

  # wakes up any sleepers that need to be woken and
  # returns an interval to IO.select on
  def schedule_sleepers
    max = nil
    now = Time.now
    fibs = []
    ZZ.delete_if { |fib, time|
      if now >= time
        fibs << fib
      else
        max = time
        false
      end
    }
    fibs.each { |fib| fib.resume }
    now = Time.now
    max.nil? || max > (now + 1) ? 1 : max - now
  end

  def wait_headers_readable(client)
    io = client.to_io
    expire = nil
    begin
      return io.recv_nonblock(1, Socket::MSG_PEEK)
    rescue Errno::EAGAIN
      return if expire && expire < Time.now
      expire ||= Time.now + G.kato
      client.wait_readable
      retry
    end
  end

  def process(client)
    G.cur += 1
    process_client(client)
  ensure
    G.cur -= 1
    ZZ.delete(client.f)
  end

  def self.setup(klass, app)
    require 'rainbows/fiber/body'
    klass.__send__(:include, Rainbows::Fiber::Body)
    self.const_set(:APP, app)
  end
end
