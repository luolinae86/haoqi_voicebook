# frozen_string_literal: true

# == Schema Information
#
# Table name: leaderboard_items
#
#  leaderboard_id :bigint           not null, comment: '排行榜ID'
#  book_id        :bigint           not null, comment: '图书ID'
#  rank           :integer          not null, comment: '排名'
#  score          :decimal          default(0.0), comment: '得分'
#
class LeaderboardItem < ApplicationRecord
  belongs_to :leaderboard
  belongs_to :book

  scope :ordered, -> { order(:rank) }
end
