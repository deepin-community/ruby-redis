require 'gem2deb/rake/testtask'

TMP                = "tmp"
BUILD_DIR          = File.join(TMP, "cache", "redis")
BINARY             = "/usr/bin/redis-server"
REDIS_CLIENT       = "/usr/bin/redis-cli"
REDIS_TRIB         = "/usr/share/doc/redis-tools/examples/redis-trib.rb"
PID_PATH           = File.join(TMP, "redis.pid")
SOCKET_PATH        = File.join(TMP, "redis.sock")
PORT               = 6381
SLAVE_PORT         = 6382
SLAVE_PID_PATH     = File.join(TMP, "redis_slave.pid")
SLAVE_SOCKET_PATH  = File.join(TMP, "redis_slave.sock")
SENTINEL_PORTS     = [ 6400, 6401, 6402 ]
SENTINEL_PID_PATHS = SENTINEL_PORTS.map { |port| File.join(TMP, "redis#{port}.pid") }
CLUSTER_PORTS      = [ 7000, 7001, 7002, 7003, 7004, 7005 ]
CLUSTER_PID_PATHS  = CLUSTER_PORTS.map { |port| File.join(TMP, "redis#{port}.pid") }
CLUSTER_CONF_PATHS = CLUSTER_PORTS.map { |port| File.join(TMP, "nodes#{port}.conf") }
CLUSTER_ADDRS      = CLUSTER_PORTS.map { |port| "127.0.0.1:#{port}" }

task :default => :all

desc "Run all the tests (start_all -> test_unit -> stop_all)"
task :all => [:start_all, :wait_ten_seconds, :test_units, :stop_all]

desc "Start all the Redis servers"
task :start_all => [:start, :start_slave, :start_sentinel, :start_cluster, :create_cluster]

desc "Stop all the Redis servers"
task :stop_all => [:stop_sentinel, :stop_slave, :stop, :stop_cluster]

task :create_tmp do
  FileUtils.mkdir_p(TMP)
end

def check_redis_running(pid_paths)
  pid_paths_arr = []

  if pid_paths.kind_of?(Array)
    pid_paths_arr.push(*pid_paths)
  else
    pid_paths_arr.push(pid_paths)
  end

  pid_paths_arr.each { |pid_path| 
    begin
      File.exists?("#{pid_path}") && Process.kill(0, File.read("#{pid_path}").to_i)
    rescue Errno::ESRCH
      FileUtils.rm "#{pid_path}"
      false
    end
  }
end

def kill_redis(pid_paths)
  pid_paths_arr = []

  if pid_paths.kind_of?(Array)
    pid_paths_arr.push(*pid_paths)
  else
    pid_paths_arr.push(pid_paths)
  end

  pid_paths_arr.each { |pid_path|
    begin
      File.exists?("#{pid_path}") && Process.kill("INT", File.read("#{pid_path}").to_i)
    rescue Errno::ESRCH
    end
    File.exists?("#{pid_path}") && FileUtils.rm("#{pid_path}")
  }
end

desc "Start the Redis server"
task :start => :create_tmp do
  unless check_redis_running(PID_PATH)
    abort "could not start redis-server"
  end

  unless system("#{BINARY}\
                    --daemonize  yes\
                    --pidfile    #{PID_PATH}\
                    --port       #{PORT}\
                    --unixsocket #{SOCKET_PATH}")
    abort "could not start redis-server"
  end
end

desc "Start the Redis server (slave)"
task :start_slave => :create_tmp do
  unless check_redis_running(SLAVE_PID_PATH)
    abort "could not start redis-server"
  end

  unless system("#{BINARY}\
                    --daemonize  yes\
                    --pidfile    #{SLAVE_PID_PATH}\
                    --port       #{SLAVE_PORT}\
                    --unixsocket #{SLAVE_SOCKET_PATH}\
                    --slaveof    127.0.0.1 #{PORT}")
    abort "could not start redis-server"
  end
end

desc "Start the Redis server (sentinel)"
task :start_sentinel => :create_tmp do
  unless check_redis_running(SENTINEL_PID_PATHS)
    abort "could not start redis-server"
  end

  SENTINEL_PORTS.each { |port|
    conf = "#{TMP}/sentinel#{port}.conf"

    File.open(conf, 'w') { |f| f.write (\
        "sentinel monitor                 master1 127.0.0.1 #{PORT} 2\n"\
        "sentinel down-after-milliseconds master1 5000\n"\
        "sentinel failover-timeout        master1 30000\n"\
        "sentinel parallel-syncs          master1 1\n")
      f.close
    }

    unless system("#{BINARY}\
                      #{conf}\
                      --daemonize  yes\
                      --pidfile    #{TMP}/redis#{port}.pid\
                      --port       #{port}\
                      --sentinel")
      abort "could not start redis-server"
    end
  }
end

desc "Start the Redis server (cluster)"
task :start_cluster => :create_tmp do
  unless check_redis_running(CLUSTER_PID_PATHS)
    abort "could not start redis-server"
  end

  CLUSTER_PORTS.each { |port|
    unless system("#{BINARY}\
                      --daemonize            yes\
                      --appendonly           yes\
                      --cluster-enabled      yes\
                      --cluster-config-file  #{TMP}/nodes#{port}.conf\
                      --cluster-node-timeout 5000\
                      --pidfile              #{TMP}/redis#{port}.pid\
                      --port                 #{port}\
                      --unixsocket           #{TMP}/redis#{port}.sock")
      abort "could not start redis-server"
    end
  }
end

desc "Stop the Redis server"
task :stop do
  kill_redis(PID_PATH)
end

desc "Stop the Redis server (slave)"
task :stop_slave do
  kill_redis(SLAVE_PID_PATH)
end

desc "Stop the Redis server (sentinel)"
task :stop_sentinel do
  kill_redis(SENTINEL_PID_PATHS)

  begin
    file = "#{TMP}/sentinel*.conf"
    Dir.glob(file) { |f| FileUtils.rm(f) }
  end

  true
end

desc "Stop the Redis server (cluster)"
task :stop_cluster do
  kill_redis(CLUSTER_PID_PATHS)

  begin
    file = "#{TMP}/appendonly.aof"
    File.exists?(file) && FileUtils.rm(file)
  end

  CLUSTER_CONF_PATHS.each { |path| File.exists?("#{path}") && FileUtils.rm("#{path}") }
  true
end

desc "Create the Redis cluster"
task :create_cluster do
  unless system("bin/cluster_creator " + CLUSTER_ADDRS.join(" "))
    abort "could not create redis cluster"
  end
end

task :clean do
end

task :wait_ten_seconds do
  sleep 10
end

Gem2Deb::Rake::TestTask.new(:test_units) do |t|
  ENV["SOCKET_PATH"] = SOCKET_PATH

  t.libs = %w(lib test)
  t.test_files = FileList["test/*_test.rb"] - FileList["test/ssl_test.rb"]
  t.options = '-v'
end
