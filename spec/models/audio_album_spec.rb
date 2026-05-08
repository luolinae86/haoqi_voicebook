# frozen_string_literal: true

require "rails_helper"

RSpec.describe AudioAlbum, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:book) }
    it { is_expected.to have_many(:audio_episodes).dependent(:destroy) }
  end

  # 验证测试
  describe "validations" do
    subject { create(:audio_album) }

    it { is_expected.to validate_presence_of(:book_id) }
    it { is_expected.to validate_uniqueness_of(:book_id) }
    it { is_expected.to validate_numericality_of(:total_episodes).is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_numericality_of(:total_duration).is_greater_than_or_equal_to(0).allow_nil }
  end

  # 实例方法测试
  describe "#formatted_duration" do
    it "正确格式化时长为 时:分:秒" do
      album = build(:audio_album, total_duration: 3661) # 1小时1分1秒
      expect(album.formatted_duration).to eq("01:01:01")
    end

    it "时长为 0 时返回 00:00:00" do
      album = build(:audio_album, total_duration: 0)
      expect(album.formatted_duration).to eq("00:00:00")
    end

    it "时长为 nil 时返回 00:00:00" do
      album = build(:audio_album, total_duration: nil)
      expect(album.formatted_duration).to eq("00:00:00")
    end

    it "正确处理整小时" do
      album = build(:audio_album, total_duration: 7200)
      expect(album.formatted_duration).to eq("02:00:00")
    end
  end
end
