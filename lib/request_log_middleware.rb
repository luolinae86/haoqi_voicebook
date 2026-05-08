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

    request = ActionDispatch::Request.new(env)
    method = request.request_method
    path = request.path
    params_str = format_params(request.filtered_parameters)

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

  def format_params(params)
    return "" if params.empty?

    filtered = params.to_unsafe_h.transform_values do |v|
      case v
      when String
        v.length > 100 ? "#{v[0..97]}..." : v
      when Array, Hash
        begin
          v.to_json
        rescue StandardError
          v.to_s
        end
      else
        v.to_s
      end
    end

    "params=#{filtered}"
  rescue StandardError
    ""
  end
end
