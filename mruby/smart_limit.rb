
Nginx.return -> do
  r = Nginx::Request.new
  c = Nginx::Connection.new

  LOCK_KEY="#{r.hostname}_list_lock"
  LIST_KEY="#{r.hostname}_waitlist"
  ACCESS_COUNTER="#{r.hostname}_c_#{Time.now.min}"
  PREV_ACCESS_COUNTER="#{r.hostname}_c_#{Time.now.min-1}"
  CONNECTION_KEY= r.headers_in['Client-Num'] || c.remote_ip

  redis = Userdata.new("redis_#{Process.pid}").redis
  begin
    skey = r.var.http_cookie.split(/;\s?/).map do |pairs|
      name, values = pairs.split('=',2)
      values if name == SLIMITER_SESSKEY
    end.compact if r.var.http_cookie

    skey = if skey && !skey.empty?
      skey.first
    else
      SecureRandom.hex
    end

    r.headers_out['Set-Cookie'] = "#{SLIMITER_SESSKEY}=#{skey}; HttpOnly;"

    s = redis.get(skey)

    Nginx.errlogger Nginx::LOG_INFO, "#{skey} value from redis:#{s}"

    if s == ACCEPT
      count_connection(redis, r.hostname, CONNECTION_KEY)
      return Nginx::DECLINED
    end

    if s
      next_sess = (a = redis.lrange(LIST_KEY, 0, 0)) ? a.first : nil
      Nginx.errlogger Nginx::LOG_INFO, "#{skey} next sess:#{next_sess}"
      if next_sess
        if next_sess == skey && redis.set(LOCK_KEY, "1", "NX" => true) == 'OK'
          begin
            last_conn = last_connection(redis, r.hostname)
            current_conn = current_connection(redis, r.hostname)
            Nginx.errlogger Nginx::LOG_INFO, "#{skey} next_sess=#{next_sess} accept last_conn:#{last_conn}, current_conn:#{current_conn}"
            if next_sess == skey && MAX_CONNECTION > last_conn  && MAX_CONNECTION > current_conn
              return Nginx::HTTP_SERVICE_UNAVAILABLE unless delete_from_list(redis, LIST_KEY, skey)
              set_accept_flg(redis, skey)
              count_connection(redis, r.hostname, CONNECTION_KEY)
              return Nginx::DECLINED
            end
          ensure
            redis.del(LOCK_KEY)
          end
        # 待ち行列の先頭が無効
        elsif (!redis.get(next_sess) || redis.get(next_sess) == ACCEPT) && redis.set(LOCK_KEY, "1", "NX" => true) == 'OK'
          begin
            delete_from_list(redis, LIST_KEY, next_sess)
          ensure
            redis.del(LOCK_KEY)
          end
        end
      end
    elsif redis.set(skey, WAITING, "NX" => true) == 'OK'
      add_wait_list(redis, LIST_KEY, skey)
    end

    redis.expire(skey, ALLOWABLE_WAITING_TTL)
    return Nginx::HTTP_SERVICE_UNAVAILABLE
  rescue => e
    Nginx.errlogger Nginx::LOG_ERR, e.inspect
    Nginx.errlogger Nginx::LOG_ERR, e.backtrace.join
    return Nginx::HTTP_SERVICE_UNAVAILABLE
  end
end.call
