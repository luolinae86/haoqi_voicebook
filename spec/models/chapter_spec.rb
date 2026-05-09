# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chapter, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:book) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe "实例方法" do
    describe "#publish!" do
      it "将章节设为已发布" do
        chapter = create(:chapter, is_published: false)
        chapter.publish!
        expect(chapter.reload.is_published).to be true
      end
    end

    describe "#unpublish!" do
      it "将章节设为未发布" do
        chapter = create(:chapter, is_published: true)
        chapter.unpublish!
        expect(chapter.reload.is_published).to be false
      end
    end

    describe "#toggle_free" do
      it "切换免费状态" do
        chapter = create(:chapter, is_free: false)
        chapter.toggle_free
        expect(chapter.reload.is_free).to be true
      end
    end
  end
end
