# frozen_string_literal: true

require "helper"

class TestDistributedCommandsOnHyperLogLog < Minitest::Test
  include Helper::Distributed
  include Lint::HyperLogLog

  def test_pfmerge
    target_version '2.8.9' do
      assert_raises Redis::Distributed::CannotDistribute do
        super
      end
    end
  end

  def test_pfcount_multiple_keys_diff_nodes
    target_version '2.8.9' do
      assert_raises Redis::Distributed::CannotDistribute do
        r.pfadd 'foo', 's1'
        r.pfadd 'bar', 's2'

        assert r.pfcount('res', 'foo', 'bar')
      end
    end
  end
end
