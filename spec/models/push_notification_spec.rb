# frozen_string_literal: true

require "rails_helper"

RSpec.describe PushNotification, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:body) }

    it "允许 title 最长 100 字符" do
      notification = build(:push_notification, title: "a" * 100)
      expect(notification).to be_valid
    end

    it "限制 title 超过 100 字符无效" do
      notification = build(:push_notification, title: "a" * 101)
      expect(notification).not_to be_valid
    end

    it "允许 body 最长 255 字符" do
      notification = build(:push_notification, body: "a" * 255)
      expect(notification).to be_valid
    end

    it "限制 body 超过 255 字符无效" do
      notification = build(:push_notification, body: "a" * 256)
      expect(notification).not_to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:push_type).with_values(system: 0, activity: 1, reminder: 2) }
    it { is_expected.to define_enum_for(:push_scope).with_values(everyone: 0, by_age: 1, by_group: 2) }
    it { is_expected.to define_enum_for(:status).with_values(draft: 0, scheduled: 1, sent: 2, failed: 3) }
  end

  describe "scopes" do
    describe ".active" do
      it "只返回未被删除的推送" do
        active = create(:push_notification, title: "通知1", is_delete: false)
        deleted = create(:push_notification, title: "已删除通知", is_delete: true)

        expect(PushNotification.active).to include(active)
        expect(PushNotification.active).not_to include(deleted)
      end
    end

    describe ".sent" do
      it "只返回已发送的推送" do
        sent = create(:push_notification, title: "已发送", status: :sent)
        draft = create(:push_notification, title: "草稿", status: :draft)

        expect(PushNotification.sent).to include(sent)
        expect(PushNotification.sent).not_to include(draft)
      end
    end

    describe ".scheduled" do
      it "只返回已调度的推送" do
        scheduled = create(:push_notification, title: "已调度", status: :scheduled)
        draft = create(:push_notification, title: "草稿", status: :draft)

        expect(PushNotification.scheduled).to include(scheduled)
        expect(PushNotification.scheduled).not_to include(draft)
      end
    end
  end

  describe "default_scope" do
    it "默认不返回已删除的推送" do
      create(:push_notification, title: "正常", is_delete: false)
      create(:push_notification, title: "已删除", is_delete: true)

      expect(PushNotification.all.map(&:title)).not_to include("已删除")
    end
  end

  describe "实例方法" do
    it "可以使用枚举状态方法" do
      notification = build(:push_notification, status: :draft)
      expect(notification.draft?).to be true
      expect(notification.sent?).to be false

      notification.status = :sent
      expect(notification.sent?).to be true
    end
  end
end
