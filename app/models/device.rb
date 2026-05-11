# frozen_string_literal: true

# 设备模型
# 一个账户可以绑定多个设备，实现多设备登录共享数据
class Device < ApplicationRecord
  belongs_to :app_user, class_name: "AppUser"

  validates :device_id, presence: true, uniqueness: true

  # 根据 device_id 查找并返回关联的 user
  def self.find_user_by_device_id(device_id)
    find_by(device_id: device_id)&.app_user
  end

  # 绑定设备到指定用户（幂等）
  def self.bind!(device_id, app_user)
    find_or_create_by!(device_id: device_id) { |d| d.app_user = app_user }
  rescue ActiveRecord::RecordNotUnique
    # 并发情况下可能已存在，重新查找
    find_by!(device_id: device_id).update!(app_user: app_user) if find_by(device_id: device_id)&.app_user_id != app_user.id
  end
end
