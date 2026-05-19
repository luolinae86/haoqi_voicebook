# frozen_string_literal: true

# == Schema Information
#
# Table name: leaderboards
#
#  name               :string           not null, comment: '榜单名称'
#  slug               :string           not null, comment: '唯一标识'
#  ranking_type       :integer          not null, default(0), comment: '0-自动 1-手动'
#  auto_rule          :string           comment: '自动规则'
#  category_filter    :string           comment: '按分类过滤'
#  limit_count        :integer          default(50), comment: '最多展示数量'
#  is_active          :boolean          not null, default(true), comment: '是否启用'
#  sort_order         :integer          not null, default(0), comment: '展示排序'
#  last_calculated_at :datetime         comment: '自动榜单最后计算时间'
#  description        :text             comment: '榜单描述'
#
FactoryBot.define do
  factory :leaderboard do
    sequence(:name) { |n| "榜单#{n}" }
    sequence(:slug) { |n| "leaderboard_#{n}" }
    ranking_type { :auto }
    is_active { true }
    sort_order { 0 }
  end
end
