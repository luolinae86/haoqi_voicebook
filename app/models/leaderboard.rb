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
class Leaderboard < ApplicationRecord
  has_many :leaderboard_items, dependent: :destroy
  has_many :books, through: :leaderboard_items

  enum :ranking_type, { auto: 0, manual: 1 }

  scope :active, -> { where(is_active: true).order(sort_order: :asc) }
  scope :auto_ranked, -> { where(ranking_type: :auto) }

  def calculate!
    return if manual? || auto_rule.blank?

    books_query = Book.all
    books_query = books_query.where(category_id: category_filter) if category_filter.present?

    book_stats = case auto_rule
                 when 'weekly_readers'
                   BookStats.joins(:book).merge(books_query).order(weekly_readers: :desc).limit(limit_count)
                 when 'monthly_readers'
                   BookStats.joins(:book).merge(books_query).order(monthly_readers: :desc).limit(limit_count)
                 when 'rating'
                   BookStats.joins(:book).merge(books_query.order(rating: :desc)).limit(limit_count)
                 when 'completion_rate'
                   BookStats.joins(:book).merge(books_query).where('book_stats.total_readers > 0').order(completion_rate: :desc).limit(limit_count)
                 when 'newest'
                   BookStats.joins(:book).merge(books_query.order(created_at: :desc)).limit(limit_count)
                 else
                   BookStats.joins(:book).merge(books_query.order(weekly_readers: :desc)).limit(limit_count)
                 end

    Leaderboard.transaction do
      leaderboard_items.destroy_all
      book_stats.each_with_index do |stats, index|
        leaderboard_items.create!(
          book_id: stats.book_id,
          rank: index + 1,
          score: stats.send(auto_rule) || 0
        )
      end
      update!(last_calculated_at: Time.current)
    end
  end
end
