# frozen_string_literal: true

# == Schema Information
#
# Table name: user_analytics_daily
#
#  id                             :bigint           not null, primary key
#  channel(渠道（NULL=全部）)     :string(32)
#  dau(日活)                      :integer          default(0)
#  mau(月活)                      :integer          default(0)
#  new_users(新注册用户)          :integer          default(0)
#  registered_users(累计注册用户) :integer          default(0)
#  retention_day_1(次日留存率)    :float(24)        default(0.0)
#  retention_day_30(30日留存率)   :float(24)        default(0.0)
#  retention_day_7(7日留存率)     :float(24)        default(0.0)
#  stat_date(日期 YYYY-MM-DD)     :string(255)      not null
#  total_sessions(总打开次数)     :integer          default(0)
#  wau(周活)                      :integer          default(0)
#
# Indexes
#
#  index_user_analytics_daily_on_stat_date_and_channel  (stat_date,channel) UNIQUE
#
require 'rails_helper'

RSpec.describe UserAnalyticsDaily, type: :model do
  describe '.upsert_daily!' do
    it 'creates a new record' do
      expect do
        described_class.upsert_daily!(
          date: Time.zone.today,
          dau: 100, wau: 500, mau: 1500,
          new_users: 10, registered_users: 1000,
          retention_day_1: 45.5, retention_day_7: 20.3, retention_day_30: 10.1,
          total_sessions: 200
        )
      end.to change(described_class, :count).by(1)

      record = described_class.find_by(stat_date: Time.zone.today.to_s, channel: nil)
      expect(record.dau).to eq(100)
      expect(record.wau).to eq(500)
      expect(record.retention_day_1).to eq(45.5)
    end

    it 'updates existing record instead of creating duplicate' do
      described_class.upsert_daily!(date: Time.zone.today, dau: 100)
      expect do
        described_class.upsert_daily!(date: Time.zone.today, dau: 150)
      end.not_to change(described_class, :count)

      record = described_class.find_by(stat_date: Time.zone.today.to_s, channel: nil)
      expect(record.dau).to eq(150)
    end

    it 'creates separate records for different channels' do
      described_class.upsert_daily!(date: Time.zone.today, dau: 100, channel: 'app_store')
      described_class.upsert_daily!(date: Time.zone.today, dau: 50, channel: 'tablet')

      expect(described_class.where(stat_date: Time.zone.today.to_s).size).to eq(2)
    end
  end

  describe 'scopes' do
    it 'filters by date' do
      described_class.upsert_daily!(date: Time.zone.today, dau: 100)
      expect(described_class.by_date(Time.zone.today)).to be_present
    end

    it 'filters global (channel nil)' do
      described_class.upsert_daily!(date: Time.zone.today, dau: 100, channel: 'app_store')
      described_class.upsert_daily!(date: Time.zone.today, dau: 200, channel: nil)
      expect(described_class.global.size).to eq(1)
    end
  end
end
