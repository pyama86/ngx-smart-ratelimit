WAITING="1"
ACCEPT="2"

ALLOWABLE_ACCESS_TTL=600
ALLOWABLE_WAITING_TTL=60
LIST_TTL=3600
SLIMITER_SESSKEY="slimiter"
MAX_CONNECTION=5

def set_accept_flg(redis, skey)
  redis.multi
    redis.set(skey, ACCEPT)
    redis.expire(skey, ALLOWABLE_ACCESS_TTL)
  redis.exec
  Nginx.errlogger Nginx::LOG_INFO, "#{skey} accept"
end

def delete_from_list(redis, list_key, skey)
  pop = redis.lpop(list_key)
  if skey != pop
    Nginx.errlogger Nginx::LOG_ERR, "different list value pop:#{pop} session:#{skey}"
    redis.lpush(list_key, pop)
    return false
  end
  return true
end

def add_wait_list(redis, list_key, skey)
  redis.multi
    redis.rpush(list_key, skey)
    redis.expire(list_key, LIST_TTL)
    redis.exec
  Nginx.errlogger Nginx::LOG_INFO, "#{skey} set value to redis"
end

def last_connection(redis, host)
  redis.scard("#{host}_#{(Time.now-60).min.to_s}")
end

def current_connection(redis, host)
  redis.scard("#{host}_#{(Time.now).min.to_s}")
end

def count_connection(redis, host, value)
  redis.multi
    redis.sadd("#{host}_#{(Time.now).min.to_s}", value)
    redis.expire("#{host}_#{(Time.now).min.to_s}", 121)
  redis.exec
end
