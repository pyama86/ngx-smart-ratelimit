redis = Redis::Retryable.new "redis", 6379
Userdata.new("redis_#{Process.pid}").redis = redis
