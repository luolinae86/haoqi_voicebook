# frozen_string_literal: true

# == Schema Information
#
# Table name: user_activity_logs
#
#  id                                       :bigint           not null, primary key
#  activity_type(类型：app_open（打开APP）) :string(32)       not null
#  channel(渠道（冗余，便于按渠道查）)      :string(32)
#  stat_date(日期 YYYY-MM-DD)               :string(255)      not null
#  created_at                               :datetime         not null
#  app_user_id(用户ID)                      :bigint           not null
#
# Indexes
#
#  idx_on_app_user_id_stat_date_activity_type_16ce7f2edf  (app_user_id,stat_date,activity_type) UNIQUE
#  index_user_activity_logs_on_channel                    (channel)
#  index_user_activity_logs_on_stat_date                  (stat_date)
#
require 'rails_helper'

RSpec.describe UserActivityLog, type: :model do
  let(:user) { create(:app_user) }

  describe '.log_app_open' do
    it 'creates a new activity log for first time today' do
      expect do
        described_class.log_app_open(user)
      end.to change(described_class, :count).by(1)

      log = described_class.last
      expect(log.app_user_id).to eq(user.id)
      expect(log.activity_type).to eq('app_open')
      expect(log.stat_date).to eq(Time.zone.today.to_s)
    end

    it 'does not create duplicate for same user same day' do
      described_class.log_app_open(user)
      expect do
        described_class.log_app_open(user)
      end.not_to change(described_class, :count)
    end

    it 'records channel from parameter' do
      described_class.log_app_open(user, channel: 'app_store')
      expect(described_class.last.channel).to eq('app_store')
    end

    it 'falls back to user channel when not provided' do
      user.update!(channel: 'tablet')
      described_class.log_app_open(user)
      expect(described_class.last.channel).to eq('tablet')
    end

    it 'creates new log for next day' do
      described_class.log_app_open(user)
      tomorrow = Time.zone.today + 1.day
      Timecop.freeze(tomorrow) do
        expect do
          described_class.log_app_open(user)
        end.to change(described_class, :count).by(1)
      end
    end
  end

  describe 'scopes' do
    it 'filters by date' do
      log = described_class.log_app_open(user)
      expect(described_class.by_date(Time.zone.today)).to include(log)
    end

    it 'filters by channel' do
      user1 = create(:app_user)
      user2 = create(:app_user)
      described_class.log_app_open(user1, channel: 'app_store')
      described_class.log_app_open(user2, channel: 'tablet')
      expect(described_class.by_channel('app_store').size).to eq(1)
    end
  end
end
