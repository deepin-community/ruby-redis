# frozen_string_literal: true

require "helper"

class TestHelper < Minitest::Test
  include Helper

  def test_version_comparison
    v = Version.new("2.0.1")

    assert v > "1"
    assert v > "2"
    assert v < "3"
    assert v < "10"

    assert v < "2.1"
    assert v < "2.0.2"
    assert v < "2.0.1.1"
    assert v < "2.0.10"

    assert v == "2.0.1"
  end
end
