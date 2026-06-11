# frozen_string_literal: true

# == Schema Information
#
# Table name: splash_ads
#
#  id           :bigint           not null, primary key
#  click_count  :integer          default(0)
#  grade_ids    :json
#  image_url    :string(255)      not null
#  link_type    :string(255)      not null
#  pad_image_url: string(255)
#  push_scope   :string(255)      default("all_users"), not null
#  send_count   :integer          default(0)
#  status       :string(255)      default("draft"), not null
#  start_time   :datetime         not null
#  end_time     :datetime         not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :splash_ad do
    image_url { 'splash_ads/test_image.png' }
    link_type { 'collection' }
    compilation_id { 1 }
    push_scope { 'all_users' }
    status { 'active' }
    start_time { 1.day.ago }
    end_time { 1.day.from_now }
    send_count { 0 }
    click_count { 0 }
  end
end
