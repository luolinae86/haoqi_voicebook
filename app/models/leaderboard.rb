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
class Leaderboard < ApplicationRecord
  has_many :leaderboard_items, dependent: :destroy
  has_many :books, through: :leaderboard_items

  enum :ranking_type, { auto: 0, manual: 1 }

  scope :active, -> { where(is_active: true).order(sort_order: :asc) }
  scope :auto_ranked, -> { where(ranking_type: :auto) }

  def calculate!
    return if manual? || auto_rule.blank?

    books_query = Book.published_books
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
