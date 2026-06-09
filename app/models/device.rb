# frozen_string_literal: true

# 设备模型
# 一个账户可以绑定多个设备，实现多设备登录共享数据
# == Schema Information
#
# Table name: devices
#
#  id          :bigint           not null, primary key
#  push_cid    :string(64)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  app_user_id :bigint           not null
#  device_id   :string(64)       not null
#
# Indexes
#
#  index_devices_on_app_user_id  (app_user_id)
#  index_devices_on_device_id    (device_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (app_user_id => app_users.id)
#
class Device < ApplicationRecord
  belongs_to :app_user, class_name: 'AppUser', optional: true

  validates :device_id, presence: true, uniqueness: true

  # 根据 device_id 查找并返回关联的 user
  def self.find_user_by_device_id(device_id)
    find_by(device_id: device_id)&.app_user
  end

  # 绑定设备到指定用户（幂等，支持重新绑定已解绑设备）
  def self.bind!(device_id, app_user)
    device = find_or_create_by!(device_id: device_id) { |d| d.app_user = app_user }
    device.update_column(:app_user_id, app_user.id) if device.app_user_id.nil?
    device
  rescue ActiveRecord::RecordNotUnique
    # 并发情况下可能已存在，重新查找
    device = find_by(device_id: device_id)
    device&.update_column(:app_user_id, app_user.id) if device&.app_user_id.nil?
  end

  # 解绑设备（退出登录，将 app_user_id 置空）
  def self.unbind!(device_id)
    device = find_by(device_id: device_id)
    device&.update_column(:app_user_id, nil)
    device
  end
end
