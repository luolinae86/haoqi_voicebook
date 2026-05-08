# frozen_string_literal: true

# 会员相关 API 挂载
module Api
  module Memberships
    class Mount < Grape::API
      mount Api::Memberships::MembershipApi
    end
  end
end
