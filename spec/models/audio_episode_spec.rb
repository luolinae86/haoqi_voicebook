# frozen_string_literal: true

require "rails_helper"

RSpec.describe AudioEpisode, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:audio_album) }
  end

  # 验证测试
  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:sort_order) }
    it { is_expected.to validate_numericality_of(:duration).is_greater_than(0).allow_nil }
    it { is_expected.to validate_numericality_of(:play_count).is_greater_than_or_equal_to(0).allow_nil }
  end

  # 作用域测试
  describe "scopes" do
    describe ".ordered" do
      it "按 sort_order 升序排列" do
        album = create(:audio_album)
        ep3 = create(:audio_episode, audio_album: album, sort_order: 3)
        ep1 = create(:audio_episode, audio_album: album, sort_order: 1)
        ep2 = create(:audio_episode, audio_album: album, sort_order: 2)

        expect(album.audio_episodes.ordered).to eq([ep1, ep2, ep3])
      end
    end

    describe ".free_episodes" do
      it "只返回免费节目" do
        album = create(:audio_album)
        free_ep = create(:audio_episode, audio_album: album, is_free: true)
        paid_ep = create(:audio_episode, audio_album: album, is_free: false)

        expect(AudioEpisode.free_episodes).to include(free_ep)
        expect(AudioEpisode.free_episodes).not_to include(paid_ep)
      end
    end

    describe ".vip_episodes" do
      it "只返回 VIP 节目" do
        album = create(:audio_album)
        vip_ep = create(:audio_episode, audio_album: album, is_vip: true)
        free_ep = create(:audio_episode, audio_album: album, is_vip: false)

        expect(AudioEpisode.vip_episodes).to include(vip_ep)
        expect(AudioEpisode.vip_episodes).not_to include(free_ep)
      end
    end

    describe ".published" do
      it "只返回已发布的节目" do
        album = create(:audio_album)
        published_ep = create(:audio_episode, audio_album: album, published_at: 1.hour.ago)
        future_ep = create(:audio_episode, audio_album: album, published_at: 1.day.from_now)

        expect(AudioEpisode.published).to include(published_ep)
        expect(AudioEpisode.published).not_to include(future_ep)
      end
    end
  end

  # 实例方法测试
  describe "#formatted_duration" do
    it "正确格式化时长为 分:秒" do
      episode = build(:audio_episode, duration: 125) # 2分5秒
      expect(episode.formatted_duration).to eq("02:05")
    end

    it "时长为 nil 时返回 00:00" do
      episode = build(:audio_episode, duration: nil)
      expect(episode.formatted_duration).to eq("00:00")
    end

    it "时长为 0 时返回 00:00" do
      episode = build(:audio_episode, duration: 0)
      expect(episode.formatted_duration).to eq("00:00")
    end
  end
end
