# frozen_string_literal: true

# API认证工厂
# == Schema Information
#
# Table name: api_auths(API认证表)
#
#  id                            :bigint           not null, primary key
#  access_key_secret(客户端密钥) :string(255)      not null
#  name(客户端名称)              :string(255)      not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  access_key_id(客户端ID)       :string(255)      not null
#
# Indexes
#
#  index_api_auths_on_access_key_id  (access_key_id) UNIQUE
#
FactoryBot.define do
  factory :api_auth do
    name { Faker::App.name }
    access_key_id { SecureRandom.hex(16) }
    access_key_secret { SecureRandom.hex(32) }
  end
end
