# frozen_string_literal: true

require "helper"
require 'lint/authentication'

class TestConnectionHandling < Minitest::Test
  include Helper::Client
  include Lint::Authentication

  def test_id
    commands = {
      client: ->(cmd, name) { @name = [cmd, name]; "+OK" },
      ping: -> { "+PONG" }
    }

    redis_mock(commands, id: "client-name") do |redis|
      assert_equal "PONG", redis.ping
    end

    assert_equal ["setname", "client-name"], @name
  end

  def test_ping
    assert_equal "PONG", r.ping
  end

  def test_select
    r.set "foo", "bar"

    r.select 14
    assert_nil r.get("foo")

    r._client.disconnect

    assert_nil r.get("foo")
  end

  def test_quit
    r.quit

    assert !r._client.connected?
  end

  def test_close
    quit = 0

    commands = {
      quit: lambda do
        quit += 1
        "+OK"
      end
    }

    redis_mock(commands) do |redis|
      assert_equal 0, quit

      redis.quit

      assert_equal 1, quit

      redis.ping

      redis.close

      assert_equal 1, quit

      assert !redis.connected?
    end
  end

  def test_disconnect
    quit = 0

    commands = {
      quit: lambda do
        quit += 1
        "+OK"
      end
    }

    redis_mock(commands) do |redis|
      assert_equal 0, quit

      redis.quit

      assert_equal 1, quit

      redis.ping

      redis.disconnect!

      assert_equal 1, quit

      assert !redis.connected?
    end
  end

  def test_shutdown
    commands = {
      shutdown: -> { :exit }
    }

    redis_mock(commands) do |redis|
      # SHUTDOWN does not reply: test that it does not raise here.
      assert_nil redis.shutdown
    end
  end

  def test_shutdown_with_error
    connections = 0
    commands = {
      select: ->(*_) { connections += 1; "+OK\r\n" },
      connections: -> { ":#{connections}\r\n" },
      shutdown: -> { "-ERR could not shutdown\r\n" }
    }

    redis_mock(commands) do |redis|
      connections = redis.connections

      # SHUTDOWN replies with an error: test that it gets raised
      assert_raises Redis::CommandError do
        redis.shutdown
      end

      # The connection should remain in tact
      assert_equal connections, redis.connections
    end
  end

  def test_shutdown_from_pipeline
    commands = {
      shutdown: -> { :exit }
    }

    redis_mock(commands) do |redis|
      result = redis.pipelined do
        redis.shutdown
      end

      assert_nil result
      assert !redis._client.connected?
    end
  end

  def test_shutdown_with_error_from_pipeline
    connections = 0
    commands = {
      select: ->(*_) { connections += 1; "+OK\r\n" },
      connections: -> { ":#{connections}\r\n" },
      shutdown: -> { "-ERR could not shutdown\r\n" }
    }

    redis_mock(commands) do |redis|
      connections = redis.connections

      # SHUTDOWN replies with an error: test that it gets raised
      assert_raises Redis::CommandError do
        redis.pipelined do
          redis.shutdown
        end
      end

      # The connection should remain in tact
      assert_equal connections, redis.connections
    end
  end

  def test_shutdown_from_multi_exec
    commands = {
      multi: -> { "+OK\r\n" },
      shutdown: -> { "+QUEUED\r\n" },
      exec: -> { :exit }
    }

    redis_mock(commands) do |redis|
      result = redis.multi do
        redis.shutdown
      end

      assert_nil result
      assert !redis._client.connected?
    end
  end

  def test_shutdown_with_error_from_multi_exec
    connections = 0
    commands = {
      select: ->(*_) { connections += 1; "+OK\r\n" },
      connections: -> { ":#{connections}\r\n" },
      multi: -> { "+OK\r\n" },
      shutdown: -> { "+QUEUED\r\n" },
      exec: -> { "*1\r\n-ERR could not shutdown\r\n" }
    }

    redis_mock(commands) do |redis|
      connections = redis.connections

      # SHUTDOWN replies with an error: test that it gets returned
      # We should test for Redis::CommandError here, but hiredis doesn't yet do
      # custom error classes.
      err = nil

      begin
        redis.multi { redis.shutdown }
      rescue => err
      end

      assert err.is_a?(StandardError)

      # The connection should remain intact
      assert_equal connections, redis.connections
    end
  end

  def test_slaveof
    redis_mock(slaveof: ->(host, port) { "+SLAVEOF #{host} #{port}" }) do |redis|
      assert_equal "SLAVEOF somehost 6381", redis.slaveof("somehost", 6381)
    end
  end

  def test_bgrewriteaof
    redis_mock(bgrewriteaof: -> { "+BGREWRITEAOF" }) do |redis|
      assert_equal "BGREWRITEAOF", redis.bgrewriteaof
    end
  end

  def test_config_get
    refute_nil r.config(:get, "*")["timeout"]

    config = r.config(:get, "timeout")
    assert_equal ["timeout"], config.keys
    assert !config.values.compact.empty?
  end

  def test_config_set
    assert_equal "OK", r.config(:set, "timeout", 200)
    assert_equal "200", r.config(:get, "*")["timeout"]

    assert_equal "OK", r.config(:set, "timeout", 100)
    assert_equal "100", r.config(:get, "*")["timeout"]
  ensure
    r.config :set, "timeout", 300
  end

  driver(:ruby, :hiredis) do
    def test_consistency_on_multithreaded_env
      t = nil

      commands = {
        set: ->(_key, _value) { t.kill; "+OK\r\n" },
        incr: ->(_key) { ":1\r\n" }
      }

      redis_mock(commands) do |redis|
        t = Thread.new do
          redis.set("foo", "bar")
        end

        t.join

        assert_equal 1, redis.incr("baz")
      end
    end
  end
end
