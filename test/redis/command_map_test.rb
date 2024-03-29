# frozen_string_literal: true

require "helper"

class TestCommandMap < Minitest::Test
  include Helper::Client

  def test_override_existing_commands
    r.set("counter", 1)

    assert_equal 2, r.incr("counter")

    r._client.command_map[:incr] = :decr

    assert_equal 1, r.incr("counter")
  end

  def test_override_non_existing_commands
    r.set("key", "value")

    assert_raises Redis::CommandError do
      r.idontexist("key")
    end

    r._client.command_map[:idontexist] = :get

    assert_equal "value", r.idontexist("key")
  end
end
