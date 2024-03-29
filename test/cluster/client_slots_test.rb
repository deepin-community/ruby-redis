# frozen_string_literal: true

require "helper"

# ruby -w -Itest test/cluster_client_slots_test.rb
class TestClusterClientSlots < Minitest::Test
  include Helper::Cluster

  def test_slot_class
    slot = Redis::Cluster::Slot.new('127.0.0.1:7000' => [1..10])

    assert_equal false, slot.exists?(0)
    assert_equal true, slot.exists?(1)
    assert_equal true, slot.exists?(10)
    assert_equal false, slot.exists?(11)

    assert_nil slot.find_node_key_of_master(0)
    assert_nil slot.find_node_key_of_slave(0)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_master(1)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_slave(1)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_master(10)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_slave(10)
    assert_nil slot.find_node_key_of_master(11)
    assert_nil slot.find_node_key_of_slave(11)

    assert_nil slot.put(1, '127.0.0.1:7001')
  end

  def test_slot_class_with_multiple_slot_ranges
    slot = Redis::Cluster::Slot.new('127.0.0.1:7000' => [1..10, 30..40])

    assert_equal false, slot.exists?(0)
    assert_equal true, slot.exists?(1)
    assert_equal true, slot.exists?(10)
    assert_equal false, slot.exists?(11)
    assert_equal true, slot.exists?(30)
    assert_equal true, slot.exists?(40)
    assert_equal false, slot.exists?(41)

    assert_nil slot.find_node_key_of_master(0)
    assert_nil slot.find_node_key_of_slave(0)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_master(1)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_slave(1)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_master(10)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_slave(10)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_slave(30)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_slave(40)
    assert_nil slot.find_node_key_of_master(11)
    assert_nil slot.find_node_key_of_slave(11)
    assert_nil slot.find_node_key_of_master(41)
    assert_nil slot.find_node_key_of_slave(41)

    assert_nil slot.put(1, '127.0.0.1:7001')
    assert_nil slot.put(30, '127.0.0.1:7001')
  end

  def test_slot_class_with_node_flags_and_replicas
    slot = Redis::Cluster::Slot.new({ '127.0.0.1:7000' => [1..10], '127.0.0.1:7001' => [1..10] },
                                    { '127.0.0.1:7000' => 'master', '127.0.0.1:7001' => 'slave' },
                                    true)

    assert_equal false, slot.exists?(0)
    assert_equal true, slot.exists?(1)
    assert_equal true, slot.exists?(10)
    assert_equal false, slot.exists?(11)

    assert_nil slot.find_node_key_of_master(0)
    assert_nil slot.find_node_key_of_slave(0)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_master(1)
    assert_equal '127.0.0.1:7001', slot.find_node_key_of_slave(1)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_master(10)
    assert_equal '127.0.0.1:7001', slot.find_node_key_of_slave(10)
    assert_nil slot.find_node_key_of_master(11)
    assert_nil slot.find_node_key_of_slave(11)

    assert_nil slot.put(1, '127.0.0.1:7002')
  end

  def test_slot_class_with_node_flags_replicas_and_slot_range
    slot = Redis::Cluster::Slot.new({ '127.0.0.1:7000' => [1..10, 30..40], '127.0.0.1:7001' => [1..10, 30..40] },
                                    { '127.0.0.1:7000' => 'master', '127.0.0.1:7001' => 'slave' },
                                    true)

    assert_equal false, slot.exists?(0)
    assert_equal true, slot.exists?(1)
    assert_equal true, slot.exists?(10)
    assert_equal false, slot.exists?(11)
    assert_equal true, slot.exists?(30)
    assert_equal false, slot.exists?(41)

    assert_nil slot.find_node_key_of_master(0)
    assert_nil slot.find_node_key_of_slave(0)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_master(1)
    assert_equal '127.0.0.1:7001', slot.find_node_key_of_slave(1)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_master(10)
    assert_equal '127.0.0.1:7001', slot.find_node_key_of_slave(10)
    assert_nil slot.find_node_key_of_master(11)
    assert_nil slot.find_node_key_of_slave(11)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_master(30)
    assert_equal '127.0.0.1:7001', slot.find_node_key_of_slave(30)
    assert_nil slot.find_node_key_of_master(41)
    assert_nil slot.find_node_key_of_slave(41)

    assert_nil slot.put(1, '127.0.0.1:7002')
  end

  def test_slot_class_with_node_flags_and_without_replicas
    slot = Redis::Cluster::Slot.new({ '127.0.0.1:7000' => [1..10], '127.0.0.1:7001' => [1..10] },
                                    { '127.0.0.1:7000' => 'master', '127.0.0.1:7001' => 'slave' },
                                    false)

    assert_equal false, slot.exists?(0)
    assert_equal true, slot.exists?(1)
    assert_equal true, slot.exists?(10)
    assert_equal false, slot.exists?(11)

    assert_nil slot.find_node_key_of_master(0)
    assert_nil slot.find_node_key_of_slave(0)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_master(1)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_slave(1)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_master(10)
    assert_equal '127.0.0.1:7000', slot.find_node_key_of_slave(10)
    assert_nil slot.find_node_key_of_master(11)
    assert_nil slot.find_node_key_of_slave(11)

    assert_nil slot.put(1, '127.0.0.1:7002')
  end

  def test_slot_class_with_empty_slots
    slot = Redis::Cluster::Slot.new({})

    assert_equal false, slot.exists?(0)
    assert_equal false, slot.exists?(1)

    assert_nil slot.find_node_key_of_master(0)
    assert_nil slot.find_node_key_of_slave(0)
    assert_nil slot.find_node_key_of_master(1)
    assert_nil slot.find_node_key_of_slave(1)

    assert_nil slot.put(1, '127.0.0.1:7001')
  end

  def test_redirection_when_slot_is_resharding
    100.times { |i| redis.set("{key}#{i}", i) }

    redis_cluster_resharding(12_539, src: '127.0.0.1:7002', dest: '127.0.0.1:7000') do
      100.times { |i| assert_equal i.to_s, redis.get("{key}#{i}") }
    end
  end
end
