# frozen_string_literal: true

# == Schema Information
#
# Table name: leaderboard_items(排行榜项表)
#
#  id                       :bigint           not null, primary key
#  rank(排名)               :integer          not null
#  score(得分)              :decimal(10, 2)   default(0.0)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  book_id(图书ID)          :bigint           not null
#  leaderboard_id(排行榜ID) :bigint           not null
#
# Indexes
#
#  index_leaderboard_items_on_leaderboard_id              (leaderboard_id)
#  index_leaderboard_items_on_leaderboard_id_and_book_id  (leaderboard_id,book_id) UNIQUE
#  index_leaderboard_items_on_leaderboard_id_and_rank     (leaderboard_id,rank)
#
class LeaderboardItem < ApplicationRecord
  belongs_to :leaderboard
  belongs_to :book

  scope :ordered, -> { order(:rank) }
end
