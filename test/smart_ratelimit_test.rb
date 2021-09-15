def redis
  @redis = Redis.new "127.0.0.1", 6379
end

def subject
  SmartRateLimit.new(redis: redis, cookie: "waiting_key=abcd;", hostname: "example.com", count_key: "192.168.1.1")
end

assert('SmartRateLimit.session_key when new') do
  sm = SmartRateLimit.new(redis: redis, cookie: "hoge=abcd;", hostname: "example.com", count_key: "192.168.1.1")
  s = sm.session_key
  assert_equal 32, s.size
  assert_equal s, sm.session_key
end

assert('SmartRateLimit.session_key when exist') do
  assert_equal "abcd", subject.session_key
end

assert('SmartRateLimit.cookie_key') do
  assert_equal "waiting_key", subject.cookie_key
end

assert('SmartRateLimit.sesssion_value') do
  redis.set("abcd", "fuga")
  assert_equal "fuga", subject.session_value
end

assert('SmartRateLimit.target_ext') do
  assert_false subject.target_ext? "jpg"
  assert_false subject.target_ext? "jpeg"
  assert_false subject.target_ext? "png"
end

assert('SmartRateLimit.sesssion_value') do
  subject.extend_ttl
  assert_equal 20, redis.ttl("abcd")
end

assert('SmartRateLimit.accept?') do
  redis.del("abcd")
  assert_false subject.accept?
  redis.set("abcd", "2")
  assert_true subject.accept?
end

assert('SmartRateLimit.can_access_if_at_the_begining when begining session') do
  redis.del("abcd")
  redis.del("example.com_waitlist")
  redis.del("example.com_#{(Time.now-60).min.to_s}")
  redis.del("example.com_#{(Time.now).min.to_s}")

  redis.lpush("example.com_waitlist", "abcd")
  redis.set("abcd", "1")

  assert_true subject.can_access_if_at_the_begining
  assert_equal "2", redis.get("abcd")
  assert_nil redis.get("example.com_list_lock")
  assert_equal 1, redis.scard("example.com_#{(Time.now).min.to_s}")
  assert_equal 0, redis.llen("example.com_waitlist")
end

assert('SmartRateLimit.can_access_if_at_the_begining when over maxconnection') do
  redis.del("abcd")
  redis.del("example.com_waitlist")
  redis.del("example.com_#{(Time.now-60).min.to_s}")
  redis.del("example.com_#{(Time.now).min.to_s}")

  11.times do |i|
    redis.sadd("example.com_#{(Time.now).min.to_s}", i.to_s)
  end

  redis.lpush("example.com_waitlist", "abcd")
  redis.set("abcd", "1")

  assert_false subject.can_access_if_at_the_begining
  assert_equal "1", redis.get("abcd")
  assert_nil redis.get("example.com_list_lock")
  assert_equal 11, redis.scard("example.com_#{(Time.now).min.to_s}")
  assert_equal 1, redis.llen("example.com_waitlist")
end

assert('SmartRateLimit.can_access_if_at_the_begining when leave begining session') do
  redis.del("abcd")
  redis.del("example.com_waitlist")
  redis.del("example.com_#{(Time.now-60).min.to_s}")
  redis.del("example.com_#{(Time.now).min.to_s}")

  redis.lpush("example.com_waitlist", "abcd")
  redis.lpush("example.com_waitlist", "efgh")
  redis.set("abcd", "1")

  assert_false subject.can_access_if_at_the_begining
  assert_equal 1, redis.llen("example.com_waitlist")
  assert_equal "1", redis.get("abcd")
  assert_nil redis.get("example.com_list_lock")
  assert_equal "abcd", redis.lpop("example.com_waitlist")
end

assert('SmartRateLimit.can_access_if_at_the_begining when session_value nil') do
  redis.del("abcd")
  redis.del("example.com_waitlist")
  assert_false subject.can_access_if_at_the_begining
  assert_equal "1", redis.get("abcd"), "1"
  assert_equal 1, redis.llen("example.com_waitlist")
  assert_equal "abcd", redis.lpop("example.com_waitlist")
  assert_nil redis.get("example.com_list_lock")
end
