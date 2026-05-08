# frozen_string_literal: true

require "rack/request"

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
    raw_body = ""

    # 用 RewindableInput 包装 rack.input，确保 body 可被多次读取
    if env["rack.input"]
      begin
        env["rack.input"] = Rack::RewindableInput.new(env["rack.input"])
        env["rack.input"].rewind
        raw_body = env["rack.input"].read.to_s
        env["rack.input"].rewind
      rescue StandardError
        raw_body = ""
      end
    end

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
    params_str = collect_params(env, raw_body)

    formatted = "[#{start_time.strftime('%Y-%m-%d %H:%M:%S %z')}] " \
                "INFO -- #{status} -- " \
                "db=#{db_runtime} total=#{total_ms} view=#{view_ms} -- " \
                "#{method} #{path}#{params_str}"

    @logger&.info(formatted)

    [status, headers, body]
  end

  private

  def setup_logger
    @logger = Logger.new(@log_path, 10, 100.megabytes)
    @logger.formatter = proc { |_severity, _time, _progname, msg| "#{msg}\n" }
  end

  def collect_params(env, raw_body)
    params = {}

    # Query string parameters
    if env["QUERY_STRING"].present?
      Rack::Utils.parse_query(env["QUERY_STRING"]).each do |k, v|
        params[k] = v
      end
    end

    # POST body parameters — 优先按 JSON 解析，失败再按 form 解析，再失败直接输出 raw body
    if raw_body.present?
      begin
        parsed = JSON.parse(raw_body)
        parsed.each { |k, v| params[k] = v } if parsed.is_a?(Hash)
      rescue JSON::ParserError
        # 尝试解析为 form-urlencoded
        parsed = Rack::Utils.parse_query(raw_body)
        parsed.each { |k, v| params[k] = v } unless parsed.empty?
      rescue StandardError
        # multipart/form-data 等无法解析的格式，直接输出 raw body 片段
        params[:_body] = raw_body.length > 200 ? "#{raw_body[0..197]}..." : raw_body
      end

      # 如果 form 解析也失败了（如 multipart），输出 raw body 片段
      if params.empty? && raw_body.present?
        params[:_body] = raw_body.length > 200 ? "#{raw_body[0..197]}..." : raw_body
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
