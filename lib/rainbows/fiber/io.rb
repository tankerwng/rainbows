# -*- encoding: binary -*-

# A Fiber-aware IO class, gives users the illusion of a synchronous
# interface that yields away from the current Fiber whenever
# the underlying descriptor is blocked on reads or write
#
# This is a stable, legacy interface and should be preserved for all
# future versions of Rainbows!  However, new apps should use
# Rainbows::Fiber::IO::Socket or Rainbows::Fiber::IO::Pipe instead.

class Rainbows::Fiber::IO
  attr_accessor :to_io

  # :stopdoc:
  class << self
    alias :[] :new
  end
  # :startdoc:

  # needed to write errors with
  def write_nonblock(buf)
    @to_io.write_nonblock(buf)
  end

  def kgio_addr
    @to_io.kgio_addr
  end

  # for wrapping output response bodies
  def each(&block)
    buf = readpartial(16384)
    yield buf
    yield buf while readpartial(16384, buf)
    rescue EOFError
      self
  end

  def closed?
    @to_io.closed?
  end

  def fileno
    @to_io.fileno
  end

  def write(buf)
    if @to_io.respond_to?(:kgio_trywrite)
      begin
        case rv = @to_io.kgio_trywrite(buf)
        when nil
          return
        when String
          buf = rv
        when Kgio::WaitWritable
          wait_writable
        end
      end while true
    else
      begin
        (rv = @to_io.write_nonblock(buf)) == buf.bytesize and return
        buf = byte_slice(buf, rv..-1)
      rescue Errno::EAGAIN
        wait_writable
      end while true
    end
  end

  def byte_slice(buf, range) # :nodoc:
    if buf.encoding != Encoding::BINARY
      buf.dup.force_encoding(Encoding::BINARY)[range]
    else
      buf[range]
    end
  end

  # used for reading headers (respecting keepalive_timeout)
  def read_timeout
    expire = nil
    begin
      return @to_io.read_nonblock(16384)
    rescue Errno::EAGAIN
      return if expire && expire < Time.now
      expire ||= Time.now + G.kato
      wait_readable
    end while true
  end

  def readpartial(length, buf = "")
    if @to_io.respond_to?(:kgio_tryread)
      begin
        rv = @to_io.kgio_tryread(length, buf)
        case rv
        when nil
          raise EOFError, "end of file reached", []
        when Kgio::WaitReadable
          wait_readable
        else
          return rv
        end
      end while true
    else
      begin
        return @to_io.read_nonblock(length, buf)
      rescue Errno::EAGAIN
        wait_readable
      end while true
    end
  end

  def kgio_read(*args)
    @to_io.kgio_read(*args)
  end

  def kgio_read!(*args)
    @to_io.kgio_read!(*args)
  end

  def kgio_trywrite(*args)
    @to_io.kgio_trywrite(*args)
  end

  autoload :Socket, 'rainbows/fiber/io/socket'
  autoload :Pipe, 'rainbows/fiber/io/pipe'
end

# :stopdoc:
require 'rainbows/fiber/io/methods'
require 'rainbows/fiber/io/compat'
Rainbows::Client.__send__(:include, Rainbows::Fiber::IO::Methods)
Rainbows::Fiber::IO.__send__(:include, Rainbows::Fiber::IO::Compat)
Rainbows::Fiber::IO.__send__(:include, Rainbows::Fiber::IO::Methods)
Kgio.wait_readable = :wait_readable
Kgio.wait_writable = :wait_writable
