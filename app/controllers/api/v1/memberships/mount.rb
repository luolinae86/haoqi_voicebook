# frozen_string_literal: true

# 会员模块挂载
module Api
  module V1
    module Memberships
      class Mount < Grape::API
        mount Api::V1::Memberships::MembershipApi
      end
    end
  end
end
