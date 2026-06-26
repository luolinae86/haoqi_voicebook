# frozen_string_literal: true

# 每日凌晨 2:05 执行统计数据聚合
# 聚合到 daily_reading_stats / daily_content_stats / daily_channel_stats
# 供 web 端直接查询
class StatsDailyAggregationWorker
  include Sidekiq::Job

  sidekiq_options queue: 'default', retry: 1

  def perform(target_date = nil)
    date = target_date ? target_date.to_date : Date.yesterday
    Rails.logger.info("[StatsDailyAggregation] Start for #{date}")

    aggregate_reading_stats(date)
    aggregate_content_stats(date)
    aggregate_channel_stats(date)

    Rails.logger.info("[StatsDailyAggregation] Done for #{date}")
  rescue StandardError => e
    Rails.logger.error("[StatsDailyAggregation] Failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    raise
  end

  private

  # 用户阅读日统计
  def aggregate_reading_stats(date)
    date_str = date.to_s

    # 从 user_reading_daily_stats 聚合
    UserReadingDailyStats.where(stat_date: date_str).find_each do |urs|
      consecutive = calculate_consecutive_days(urs.app_user_id, date)

      # 当日完读书籍数
      completed_today = ReadingProgress.where(
        app_user_id: urs.app_user_id,
        completed: true,
        completed_at: date.all_day
      ).count

      completion_rate = urs.books_read_count > 0 ? (completed_today.to_f / urs.books_read_count * 100).round(2) : 0.0
      avg_duration = urs.session_count > 0 ? (urs.total_duration_seconds / urs.session_count).round : 0

      DailyReadingStat.upsert(
        {
          app_user_id: urs.app_user_id,
          stat_date: date_str,
          session_count: urs.session_count,
          total_duration_seconds: urs.total_duration_seconds,
          books_read_count: urs.books_read_count,
          avg_duration_seconds: avg_duration,
          completed_books_count: completed_today,
          completion_rate: completion_rate,
          consecutive_days: consecutive,
          created_at: Time.current,
          updated_at: Time.current
        },
      )
    end

    count = UserReadingDailyStats.where(stat_date: date_str).count
    Rails.logger.info("[StatsDailyAggregation] reading_stats: #{count} users for #{date_str}")
  end

  # 内容日统计（按书 + 全平台汇总）
  def aggregate_content_stats(date)
    date_str = date.to_s

    # 按书聚合
    book_ids = ContentClickEvent.where(stat_date: date_str).distinct.pluck(:book_id).compact +
               MediaPlayEvent.where(stat_date: date_str).distinct.pluck(:book_id).compact
    book_ids.uniq.each do |book_id|
      book = Book.find_by(id: book_id)
      next unless book

      clicks = ContentClickEvent.where(stat_date: date_str, book_id: book_id, click_type: 'click').count
      reads = ContentClickEvent.where(stat_date: date_str, book_id: book_id, click_type: 'read')
                               .where("duration_seconds >= 30").count
      read_users = ContentClickEvent.where(stat_date: date_str, book_id: book_id, click_type: 'read')
                                    .where("duration_seconds >= 30").distinct.count(:app_user_id)

      valid_plays = MediaPlayEvent.where(stat_date: date_str, book_id: book_id, is_valid_play: true).count
      completed_plays = MediaPlayEvent.where(stat_date: date_str, book_id: book_id, event_type: 'play_complete').count
      play_users = MediaPlayEvent.where(stat_date: date_str, book_id: book_id, is_valid_play: true).distinct.count(:app_user_id)
      completed_users = ReadingProgress.where(book_id: book_id, completed: true, completed_at: date.all_day).distinct.count(:app_user_id)

      total_readers = read_users + play_users
      total_completed = completed_users
      rate = total_readers > 0 ? (total_completed.to_f / total_readers * 100).round(2) : 0.0

      DailyContentStat.upsert(
        {
          stat_date: date_str,
          book_id: book_id,
          content_type: book.content_type,
          clicks_count: clicks,
          reads_count: reads,
          valid_plays_count: valid_plays,
          completed_plays_count: completed_plays,
          read_users_count: read_users,
          play_users_count: play_users,
          completed_users_count: completed_users,
          completion_rate: rate,
          created_at: Time.current,
          updated_at: Time.current
        },
      )
    end

    # 全平台汇总（book_id = NULL）
    clicks = ContentClickEvent.where(stat_date: date_str, click_type: 'click').count
    reads = ContentClickEvent.where(stat_date: date_str, click_type: 'read').where("duration_seconds >= 30").count
    read_users = ContentClickEvent.where(stat_date: date_str, click_type: 'read').where("duration_seconds >= 30").distinct.count(:app_user_id)
    valid_plays = MediaPlayEvent.where(stat_date: date_str, is_valid_play: true).count
    completed_plays = MediaPlayEvent.where(stat_date: date_str, event_type: 'play_complete').count
    play_users = MediaPlayEvent.where(stat_date: date_str, is_valid_play: true).distinct.count(:app_user_id)
    completed_users = ReadingProgress.where(completed: true, completed_at: date.all_day).distinct.count(:app_user_id)
    total_readers = read_users + play_users
    rate = total_readers > 0 ? (completed_users.to_f / total_readers * 100).round(2) : 0.0

    DailyContentStat.upsert(
      {
        stat_date: date_str,
        book_id: nil,
        content_type: nil,
        clicks_count: clicks,
        reads_count: reads,
        valid_plays_count: valid_plays,
        completed_plays_count: completed_plays,
        read_users_count: read_users,
        play_users_count: play_users,
        completed_users_count: completed_users,
        completion_rate: rate,
        created_at: Time.current,
        updated_at: Time.current
      },
    )

    Rails.logger.info("[StatsDailyAggregation] content_stats: #{book_ids.size} books for #{date_str}")
  end

  # 渠道日统计
  def aggregate_channel_stats(date)
    date_str = date.to_s

    # 全渠道汇总
    aggregate_channel_stats_for(date, '')

    # 按各渠道分别聚合
    channels = AppUser.where.not(channel: [nil, '']).distinct.pluck(:channel).compact
    channels.each { |ch| aggregate_channel_stats_for(date, ch) }
  end

  def aggregate_channel_stats_for(date, channel)
    date_str = date.to_s

    # 当日注册量
    reg_query = AppUser.where(created_at: date.all_day)
    reg_query = reg_query.where(channel: channel) if channel
    registrations = reg_query.count

    # 当日活跃用户数（复用已有聚合）
    active_query = UserAnalyticsDaily.where(stat_date: date_str)
    active_query = active_query.where(channel: channel) if channel
    active_users = active_query.first&.dau || 0

    # 当日付费用户数 & 付费金额
    paid_query = Order.where(paid_at: date.all_day, status: :paid)
    paid_query = paid_query.where(channel: channel) if channel
    paid_users = paid_query.distinct.count(:app_user_id)
    paid_amount = paid_query.sum(:amount)

    # 转化率 = 付费用户 / 活跃用户
    conversion = active_users > 0 ? (paid_users.to_f / active_users * 100).round(2) : 0.0

    # CAC = 付费金额 / 注册量（简化：用付费金额近似获客成本）
    cac = registrations > 0 ? (paid_amount / registrations).round(2) : 0.0

    DailyChannelStat.upsert(
      {
        stat_date: date_str,
        channel: channel,
        registrations: registrations,
        active_users: active_users,
        paid_users: paid_users,
        paid_amount: paid_amount,
        conversion_rate: conversion,
        cac: cac,
        created_at: Time.current,
        updated_at: Time.current
      },
    )

    Rails.logger.info("[StatsDailyAggregation] channel_stats: #{date_str}#{" (#{channel})" if channel}: reg=#{registrations}, paid=#{paid_users}, amt=#{paid_amount}")
  end

  # 计算截至某日的连续阅读天数
  def calculate_consecutive_days(app_user_id, date)
    streak = 0
    check_date = date
    loop do
      has_read = UserReadingDailyStats.exists?(app_user_id: app_user_id, stat_date: check_date.to_s)
      break unless has_read

      streak += 1
      check_date -= 1.day
      break if streak > 365
    end
    streak
  end
end
