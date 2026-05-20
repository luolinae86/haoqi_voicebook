# frozen_string_literal: true

# 定时计算自动排行榜数据
class CalculateLeaderboardsJob
  include Sidekiq::Job

  sidekiq_options queue: "default", retry: 3

  def perform
    Leaderboard.auto_ranked.active.each do |leaderboard|
      leaderboard.calculate!
      Rails.logger.info("[CalculateLeaderboards] Calculated leaderboard: #{leaderboard.name}")
    end
  rescue StandardError => e
    Rails.logger.error("[CalculateLeaderboards] Failed: #{e.message}")
    raise
  end
end
