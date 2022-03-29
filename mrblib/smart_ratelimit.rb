class SmartRateLimit; end
module SmartRateLimit::Store; end

class SmartRateLimit
  include SmartRateLimit::Store
  attr_reader :redis, :list_key, :list_ttl, :lock_key, :hostname, :max_connection, :count_key, :allowable_waiting_ttl, :allowable_access_ttl,
              :cookie, :max_position

  def initialize(redis:, cookie:, hostname:, count_key:, allowable_access_ttl: 600, max_connection: 10, list_ttl: 3600, allowable_waiting_ttl: 20, max_position: 100)
    @redis = redis
    @cookie = cookie
    @list_ttl = list_ttl
    @lock_key = "#{hostname}_list_lock"
    @list_key = "#{hostname}_waitlist"
    @hostname = hostname
    @max_connection = max_connection
    @count_key = count_key
    @allowable_waiting_ttl = allowable_waiting_ttl
    @allowable_access_ttl = allowable_access_ttl
    @max_position = max_position
  end

  def wait_list_length
    list_length(list_key)
  end

  def can_access_if_at_the_begining
    add_wait_list(session_key) if !session_value && set_wait_flg(session_key)
    delete_begining_session_if_expired
    if permit_access?
      set_accept_flg(session_key) unless accept?
    else
      extend_ttl(session_key)
      return false
    end
    true
  end

  def cookie_key
    'waiting_key'
  end

  def target_ext?(ext)
    static_file_ext[ext]
  end

  def my_position
    position(session_key)
  end

  def accept?
    session_value == ACCEPT
  end

  def session_key
    unless @_session_key
      begin
        s = cookie.split(/;\s?/).map do |pairs|
          name, values = pairs.split('=', 2)
          values if name == cookie_key
        end.compact.first
      rescue StandardError => e
        p e
        nil
      end
      s ||= SecureRandom.hex
      @_session_key = s
    end
    @_session_key
  end

  private

  def session_value
    @_sessv ||= value(session_key)
  end

  def static_file_ext
    {
      '.less' => true,
      '.txt' => true,
      '.css' => true,
      '.js' => true,
      '.jpg' => true,
      '.jpeg' => true,
      '.gif' => true,
      '.ico' => true,
      '.png' => true,
      '.bmp' => true,
      '.pict' => true,
      '.csv' => true,
      '.doc' => true,
      '.pdf' => true,
      '.pls' => true,
      '.ppt' => true,
      '.tif' => true,
      '.tiff' => true,
      '.eps' => true,
      '.ejs' => true,
      '.swf' => true,
      '.midi' => true,
      '.mid' => true,
      '.ttf' => true,
      '.eot' => true,
      '.woff' => true,
      '.otf' => true,
      '.svg' => true,
      '.svgz' => true,
      '.webp' => true,
      '.docx' => true,
      '.xlsx' => true,
      '.xls' => true,
      '.pptx' => true,
      '.ps' => true,
      '.class' => true,
      '.jar' => true
    }
  end

  def permit_access?
    if begining_session_key == session_key && lock
      begin
        if max_connection > last_connection && max_connection > current_connection
          raise PopOtherSessionError unless delete_from_list(session_key)

          return true
        end
      ensure
        unlock
      end
    end
    false
  end

  # 先頭ユーザーが無効かすでにアクセス許可済み
  def delete_begining_session_if_expired
    return unless !begining_session_value || begining_session_value == ACCEPT

    lock
    begin
      delete_from_list(begining_session_key)
    ensure
      unlock
    end
  end

  class PopOtherSessionError < StandardError; end
end
