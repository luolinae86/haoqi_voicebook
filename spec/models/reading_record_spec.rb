# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReadingRecord, type: :model do
  # 关联测试
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:book) }
    it { should belong_to(:chapter).optional }
  end

  # 验证测试
  describe "validations" do
    it { should validate_numericality_of(:words_read).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:duration_minutes).is_greater_than_or_equal_to(0).allow_nil }
  end

  # 作用域测试
  describe "scopes" do
    describe ".today" do
      it "只返回今天的阅读记录" do
        today_record = create(:reading_record, read_at: Time.current)
        yesterday_record = create(:reading_record, read_at: 1.day.ago)

        expect(ReadingRecord.today).to include(today_record)
        expect(ReadingRecord.today).not_to include(yesterday_record)
      end
    end

    describe ".this_week" do
      it "只返回本周的阅读记录" do
        this_week_record = create(:reading_record, read_at: Time.current)
        last_week_record = create(:reading_record, read_at: 2.weeks.ago)

        expect(ReadingRecord.this_week).to include(this_week_record)
        expect(ReadingRecord.this_week).not_to include(last_week_record)
      end
    end

    describe ".this_month" do
      it "只返回本月的阅读记录" do
        this_month_record = create(:reading_record, read_at: Time.current)
        last_month_record = create(:reading_record, read_at: 2.months.ago)

        expect(ReadingRecord.this_month).to include(this_month_record)
        expect(ReadingRecord.this_month).not_to include(last_month_record)
      end
    end
  end
end
