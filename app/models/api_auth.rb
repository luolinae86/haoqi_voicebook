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
# frozen_string_literal: true

# API 认证模型
# 管理 API 客户端的认证凭据（access_key_id 和 access_key_secret）
class ApiAuth < ApplicationRecord
  # 验证规则
  validates :name, presence: true # 客户端名称
  validates :access_key_id, presence: true, uniqueness: true # 客户端 ID
  validates :access_key_secret, presence: true # 客户端密钥

  # 创建前自动生成密钥
  before_create :generate_keys

  private

  # 自动生成 access_key_id 和 access_key_secret
  def generate_keys
    self.access_key_id ||= SecureRandom.hex(16)
    self.access_key_secret ||= SecureRandom.hex(32)
  end
end
