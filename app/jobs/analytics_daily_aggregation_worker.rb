# frozen_string_literal: true

# 每日凌晨 2 点执行用户分析数据预聚合
# 计算 DAU/WAU/MAU/留存率/新注册用户等指标
# 按全量 + 各渠道分别计算
class AnalyticsDailyAggregationWorker
  include Sidekiq::Job

  sidekiq_options queue: 'default', retry: 1

  def perform(target_date = nil)
    date = target_date ? target_date.to_date : Date.yesterday
    Rails.logger.info("[AnalyticsDailyAggregation] Start aggregating for #{date}")

    aggregate_for_date(date, channel: nil)

    # 按各渠道分别聚合
    channels = AppUser.where.not(channel: nil).distinct.pluck(:channel).compact
    channels.each do |channel|
      aggregate_for_date(date, channel: channel)
    end

    Rails.logger.info("[AnalyticsDailyAggregation] Done for #{date}")
  rescue StandardError => e
    Rails.logger.error("[AnalyticsDailyAggregation] Failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    raise
  end

  private

  def aggregate_for_date(date, channel:)
    date_str = date.to_s

    # DAU：当日打开过 APP 的去重用户数
    dau_query = UserActivityLog.where(stat_date: date_str)
    dau_query = dau_query.where(channel: channel) if channel
    dau = dau_query.distinct.count(:app_user_id)

    # WAU：过去 7 天内打开过 APP 的去重用户数
    wau_start = (date - 6.days).to_s
    wau_query = UserActivityLog.where(stat_date: wau_start..date_str)
    wau_query = wau_query.where(channel: channel) if channel
    wau = wau_query.distinct.count(:app_user_id)

    # MAU：过去 30 天内打开过 APP 的去重用户数
    mau_start = (date - 29.days).to_s
    mau_query = UserActivityLog.where(stat_date: mau_start..date_str)
    mau_query = mau_query.where(channel: channel) if channel
    mau = mau_query.distinct.count(:app_user_id)

    # 新注册用户
    new_users_query = AppUser.where(created_at: date.all_day)
    new_users_query = new_users_query.where(channel: channel) if channel
    new_users = new_users_query.count

    # 累计注册用户
    registered_query = AppUser.where('created_at <= ?', date.end_of_day)
    registered_query = registered_query.where(channel: channel) if channel
    registered_users = registered_query.count

    # 留存率 = 第 N 日仍活跃的用户 / 首日注册用户
    # 次日留存：date - 1 天注册的用户，在 date 天也活跃
    retention_day_1 = calculate_retention(date, 1, channel)
    retention_day_7 = calculate_retention(date, 7, channel)
    retention_day_30 = calculate_retention(date, 30, channel)

    # 总打开次数
    sessions_query = UserActivityLog.where(stat_date: date_str)
    sessions_query = sessions_query.where(channel: channel) if channel
    total_sessions = sessions_query.count

    UserAnalyticsDaily.upsert_daily!(
      date: date,
      dau: dau, wau: wau, mau: mau,
      new_users: new_users,
      registered_users: registered_users,
      retention_day_1: retention_day_1,
      retention_day_7: retention_day_7,
      retention_day_30: retention_day_30,
      total_sessions: total_sessions,
      channel: channel
    )

    Rails.logger.info("[AnalyticsDailyAggregation] #{date_str}#{" (#{channel})" if channel}: dau=#{dau}, wau=#{wau}, mau=#{mau}, new=#{new_users}, r1=#{retention_day_1}, r7=#{retention_day_7}, r30=#{retention_day_30}")
  end

  # 计算 N 日留存率
  def calculate_retention(date, days, channel)
    (date - days).to_s
    active_date = date.to_s

    # 在 register_date 注册的用户
    registered_query = AppUser.where(created_at: days.days.ago.to_date.all_day)
    registered_query = registered_query.where(channel: channel) if channel
    registered_count = registered_query.count

    return 0.0 if registered_count.zero?

    # 这些用户在 date 天有活跃
    registered_ids = registered_query.pluck(:id)
    active_query = UserActivityLog.where(stat_date: active_date, app_user_id: registered_ids)
    active_query = active_query.where(channel: channel) if channel
    active_count = active_query.distinct.count(:app_user_id)

    (active_count.to_f / registered_count * 100).round(2)
  end
end
