# frozen_string_literal: true

# 请求日志中间件
# 格式参考 Unicorn: [时间] STATUS -- db=XX total=XX view=XX -- METHOD PATH params={...}
# 日志写入独立的 log/puma.log 文件
class RequestLogMiddleware
  def initialize(app)
    @app = app
    @log_path = Rails.root.join("log/puma.log")
    @logger = nil
    setup_logger
  end

  def call(env)
    start_time = Time.current
    db_runtime = 0

    # 订阅 SQL 事件统计 DB 耗时
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, start, finish, _id, _payload|
      db_runtime += ((finish - start) * 1000).round
    end

    begin
      status, headers, body = @app.call(env)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    end_time = Time.current
    total_ms = ((end_time - start_time) * 1000).round
    view_ms = [0, total_ms - db_runtime].max

    method = env["REQUEST_METHOD"]
    path = env["PATH_INFO"]
    params_str = collect_params(env)

    formatted = "[#{start_time.strftime('%Y-%m-%d %H:%M:%S %z')}] " \
                "INFO -- #{status} -- " \
                "db=#{db_runtime} total=#{total_ms} view=#{view_ms} -- " \
                "#{method} #{path} #{params_str}"

    @logger&.info(formatted)

    [status, headers, body]
  end

  private

  def setup_logger
    @logger = Logger.new(@log_path, 10, 100.megabytes)
    @logger.formatter = proc { |_severity, _time, _progname, msg| "#{msg}\n" }
  end

  def collect_params(env)
    params = {}

    # Query string parameters
    if env["QUERY_STRING"].present?
      Rack::Utils.parse_query(env["QUERY_STRING"]).each do |k, v|
        params[k] = v
      end
    end

    # POST body parameters (form data or JSON)
    content_type = env["CONTENT_TYPE"].to_s
    if %w[application/x-www-form-urlencoded multipart/form-data].any? { |ct| content_type.include?(ct) }
      if env["rack.input"]
        body = env["rack.input"].read
        env["rack.input"].rewind if body
        if body.present?
          if content_type.include?("multipart")
            # For multipart, just note it (parsing is complex)
            params[:_body] = "[multipart]"
          else
            Rack::Utils.parse_query(body).each do |k, v|
              params[k] = v
            end
          end
        end
      end
    elsif content_type.include?("application/json")
      if env["rack.input"]
        body = env["rack.input"].read
        env["rack.input"].rewind if body
        if body.present?
          begin
            json = JSON.parse(body)
            json.each { |k, v| params[k] = v }
          rescue JSON::ParserError
            params[:_body] = body.length > 200 ? "#{body[0..197]}..." : body
          end
        end
      end
    end

    return "" if params.empty?

    "params=#{truncate_params(params)}"
  rescue StandardError
    ""
  end

  def truncate_params(hash)
    result = {}
    hash.each do |k, v|
      result[k] = case v
                  when String
                    v.length > 200 ? "#{v[0..197]}..." : v
                  when Hash
                    truncate_params(v)
                  when Array
                    v.map { |item| item.is_a?(Hash) ? truncate_params(item) : item }
                  else
                    v
                  end
    end
    result
  end
end
