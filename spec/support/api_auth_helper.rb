# frozen_string_literal: true

# API 认证辅助方法
module ApiAuthHelper
  def auth_headers(user)
    { "uuid" => user.uuid }
  end
end

RSpec.configure do |config|
  config.include ApiAuthHelper, type: :request
end
