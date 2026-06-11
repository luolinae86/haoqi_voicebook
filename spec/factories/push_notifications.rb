# frozen_string_literal: true

# == Schema Information
#
# Table name: push_notifications
#
#  id            :bigint           not null, primary key
#  body          :string(255)      not null
#  click_count   :integer          default(0)
#  delivery_rate :decimal          default(0.00)
#  is_delete     :boolean          default("0")
#  link_url      :string(255)
#  max_age       :integer
#  min_age       :integer
#  push_scope    :integer          not null, default(0)
#  push_type     :integer          not null, default(0)
#  scheduled_at  :datetime
#  send_count    :integer          default(0)
#  sent_at       :datetime
#  status        :integer          not null, default(0)
#  title         :string(255)      not null
#  user_group    :text(65535)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
FactoryBot.define do
  factory :push_notification do
    title { "系统通知" }
    body { "这是一条测试推送通知" }
    push_type { :system }
    push_scope { :everyone }
    status { :draft }
    is_delete { false }
  end
end
