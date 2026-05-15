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
# Indexes
#
#  index_push_notifications_on_push_type  (push_type)
#  index_push_notifications_on_status     (status)
#
class PushNotification < ApplicationRecord
  enum :push_type, { system: 0, activity: 1, reminder: 2 }, default: :system
  enum :push_scope, { everyone: 0, by_age: 1, by_group: 2 }, default: :everyone
  enum :status, { draft: 0, scheduled: 1, sent: 2, failed: 3 }, default: :draft

  default_scope { where(is_delete: false) }

  validates :title, presence: true, length: { maximum: 100 }
  validates :body, presence: true, length: { maximum: 255 }

  scope :active, -> { where(is_delete: false) }
  scope :sent, -> { where(status: :sent) }
  scope :scheduled, -> { where(status: :scheduled) }
end
