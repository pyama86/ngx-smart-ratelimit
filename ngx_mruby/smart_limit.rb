MAX_CONNECTION=5

Nginx.return -> do
  r = Nginx::Request.new
  c = Nginx::Connection.new

  CONNECTION_KEY= r.headers_in['Client-Num'] || c.remote_ip

  redis = Userdata.new("redis_#{Process.pid}").redis
  begin
    smart_limit = SmartRateLimit.new(redis:redis,cookie: r.var.http_cookie, hostname: r.hostname, max_connection: MAX_CONNECTION, count_key: CONNECTION_KEY)
    r.headers_out['Set-Cookie'] = "#{smart_limit.cookie_key}=#{smart_limit.session_key}; HttpOnly; #{r.scheme == 'https' ? 'Secure;' : nil}"

    if smart_limit.accept?
      smart_limit.add_connection(CONNECTION_KEY)
      return Nginx::DECLINED
    end

    # アセットファイルはクッキーを付与しない
    return Nginx::HTTP_SERVICE_UNAVAILABLE if smart_limit.target_ext?(File.extname(r.var.request_filename))

    begin
      if smart_limit.can_access_if_at_the_begining
        return Nginx::DECLINED
      end
    rescue SmartRateLimit::PopOtherSessionError
      Nginx.errlogger Nginx::LOG_ERR, "pop other session"
      return Nginx::HTTP_SERVICE_UNAVAILABLE
    end

    smart_limit.extend_ttl
    return Nginx::HTTP_SERVICE_UNAVAILABLE
  rescue => e
    Nginx.errlogger Nginx::LOG_ERR, e.inspect
    Nginx.errlogger Nginx::LOG_ERR, e.backtrace.join
    return Nginx::HTTP_SERVICE_UNAVAILABLE
  end
end.call
