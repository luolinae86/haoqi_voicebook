# frozen_string_literal: true

# == Schema Information
#
# Table name: leaderboards(排行榜表)
#
#  id                                       :bigint           not null, primary key
#  auto_rule(自动规则)                      :string(255)
#  category_filter(按分类过滤)              :string(255)
#  description(榜单描述)                    :text(65535)
#  is_active(是否启用)                      :boolean          default(TRUE), not null
#  last_calculated_at(自动榜单最后计算时间) :datetime
#  limit_count(最多展示数量)                :integer          default(50)
#  name(榜单名称)                           :string(255)      not null
#  ranking_type(0-自动 1-手动)              :integer          default("auto"), not null
#  slug(唯一标识)                           :string(255)      not null
#  sort_order(展示排序)                     :integer          default(0), not null
#  created_at                               :datetime         not null
#  updated_at                               :datetime         not null
#
# Indexes
#
#  index_leaderboards_on_ranking_type_and_is_active  (ranking_type,is_active)
#  index_leaderboards_on_slug                        (slug) UNIQUE
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
