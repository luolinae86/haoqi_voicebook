# frozen_string_literal: true

# API 认证模型
# 管理 API 客户端的认证凭据（access_key_id 和 access_key_secret）
class ApiAuth < ApplicationRecord
  # 验证规则
  validates :name, presence: true              # 客户端名称
  validates :access_key_id, presence: true, uniqueness: true    # 客户端 ID
  validates :access_key_secret, presence: true  # 客户端密钥

  # 创建前自动生成密钥
  before_create :generate_keys

  private

  # 自动生成 access_key_id 和 access_key_secret
  def generate_keys
    self.access_key_id ||= SecureRandom.hex(16)
    self.access_key_secret ||= SecureRandom.hex(32)
  end
end
