class SmartRateLimit
  module Store
    WAITING = '1'
    ACCEPT = '2'
    def accept?
      session_value == ACCEPT
    end

    def session_value
      @_sessv ||= redis.get(session_key)
    end

    def begining_session_value
      @_bsessv ||= redis.get(begining_session_key)
    end

    def set_accept_flg
      redis.multi
      redis.set(session_key, ACCEPT)
      redis.expire(session_key, allowable_access_ttl)
      redis.exec
    end

    def set_wait_flg
      redis.set(session_key, WAITING, 'NX' => true) == 'OK'
      extend_ttl
    end

    def delete_from_list(sess_key)
      pop = redis.lpop(list_key)
      if sess_key != pop
        redis.lpush(list_key, pop)
        return false
      end
      true
    end

    def add_wait_list(sess_key)
      redis.rpush(list_key, sess_key) if !redis.exists?(list_key) || redis.sadd("#{list_key}_lock", sess_key) == 1
      redis.expire(list_key, list_ttl)
      redis.expire("#{list_key}_lock", list_ttl)
    end

    def last_connection
      @_lastconn ||= redis.scard("#{hostname}_#{(Time.now - 60).min}")
    end

    def current_connection
      @_currentconn ||= redis.scard("#{hostname}_#{Time.now.min}")
    end

    def add_connection(value)
      redis.multi
      redis.sadd("#{hostname}_#{Time.now.min}", value)
      redis.expire("#{hostname}_#{Time.now.min}", 121)
      redis.exec
    end

    def begining_session_key
      @_nextv ||= (a = redis.lrange(list_key, 0, 0)) ? a.first : nil
    end

    def lock
      redis.set(lock_key, '1', 'NX' => true) == 'OK'
    end

    def unlock
      redis.del(lock_key)
    end

    def extend_ttl
      redis.expire(session_key, allowable_waiting_ttl)
    end
  end
end
