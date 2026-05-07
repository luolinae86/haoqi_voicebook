# frozen_string_literal: true

# 为文档接口添加 HTTP Basic Auth
# 保护路径：/api_docs.html 和 /api/swagger_doc
class DocsAuthMiddleware
  PATHS = %w[/api_docs.html /api/swagger_doc /api/swagger_doc/].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"]
    return @app.call(env) unless PATHS.any? { |p| path.start_with?(p) }
    return @app.call(env) unless docs_auth_enabled?

    auth = Rack::Auth::Basic::Request.new(env)
    if auth.provided? && auth.basic?
      username, password = auth.credentials
      return @app.call(env) if username == docs_username && password == docs_password
    end

    unauthorized
  end

  private

  def docs_auth_enabled?
    ENV["DOCS_USERNAME"].present? && ENV["DOCS_PASSWORD"].present?
  end

  def docs_username
    ENV.fetch("DOCS_USERNAME", "")
  end

  def docs_password
    ENV.fetch("DOCS_PASSWORD", "")
  end

  def unauthorized
    [
      401,
      {
        "WWW-Authenticate" => 'Basic realm="API Docs Access"',
        "Content-Type" => "text/plain; charset=utf-8"
      },
      ["401 Unauthorized - 需要文档访问密码"]
    ]
  end
end
