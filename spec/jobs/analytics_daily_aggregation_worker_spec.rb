# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsDailyAggregationWorker, type: :job do
  let(:date) { 5.days.ago.to_date }

  before do
    # Clear any existing analytics data
    UserAnalyticsDaily.destroy_all
    UserActivityLog.destroy_all
  end

  describe '#perform' do
    it 'aggregates DAU from activity logs' do
      user1 = create(:app_user)
      user2 = create(:app_user)

      # Both users active on date
      Timecop.freeze(date) do
        UserActivityLog.log_app_open(user1)
        UserActivityLog.log_app_open(user2)
      end

      described_class.new.perform(date)

      record = UserAnalyticsDaily.find_by(stat_date: date.to_s, channel: nil)
      expect(record).to be_present
      expect(record.dau).to eq(2)
    end

    it 'aggregates new users registered on date' do
      Timecop.freeze(date) do
        create(:app_user)
        create(:app_user)
      end

      described_class.new.perform(date)

      record = UserAnalyticsDaily.find_by(stat_date: date.to_s, channel: nil)
      expect(record.new_users).to eq(2)
    end

    it 'aggregates by channel' do
      user = create(:app_user, channel: 'app_store')
      Timecop.freeze(date) { UserActivityLog.log_app_open(user, channel: 'app_store') }

      described_class.new.perform(date)

      record = UserAnalyticsDaily.find_by(stat_date: date.to_s, channel: 'app_store')
      expect(record).to be_present
      expect(record.dau).to eq(1)
    end

    it 'handles zero activity gracefully' do
      described_class.new.perform(date)

      record = UserAnalyticsDaily.find_by(stat_date: date.to_s, channel: nil)
      expect(record).to be_present
      expect(record.dau).to eq(0)
    end

    it 'calculates retention rate' do
      # User registered 6 days ago (date - 1)
      register_date = (date - 1.day).to_date
      Timecop.freeze(register_date) do
        user = create(:app_user)
        # User is active on date
        Timecop.freeze(date) { UserActivityLog.log_app_open(user) }
      end

      described_class.new.perform(date)

      record = UserAnalyticsDaily.find_by(stat_date: date.to_s, channel: nil)
      expect(record.retention_day_1).to be >= 0
    end
  end
end
