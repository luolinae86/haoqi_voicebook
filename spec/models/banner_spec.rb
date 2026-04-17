# frozen_string_literal: true

require "rails_helper"

RSpec.describe Banner, type: :model do
  # 验证测试
  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:image_url) }
    it { should validate_presence_of(:sort_order) }
  end

  # 枚举测试
  describe "enums" do
    it { should define_enum_for(:link_type).with_values(book: 0, collection: 1, url: 2, no_link: 3) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".active" do
      it "只返回启用且在有效期内的轮播图" do
        active_banner = create(:banner, is_active: true, starts_at: 1.day.ago, ends_at: 1.day.from_now)
        inactive_banner = create(:banner, is_active: false, starts_at: 1.day.ago, ends_at: 1.day.from_now)
        expired_banner = create(:banner, is_active: true, starts_at: 1.week.ago, ends_at: 1.day.ago)

        expect(Banner.active).to include(active_banner)
        expect(Banner.active).not_to include(inactive_banner)
        expect(Banner.active).not_to include(expired_banner)
      end
    end

    describe ".ordered" do
      it "按 sort_order 升序排列" do
        b3 = create(:banner, sort_order: 3)
        b1 = create(:banner, sort_order: 1)
        b2 = create(:banner, sort_order: 2)

        expect(Banner.ordered).to eq([b1, b2, b3])
      end
    end

    describe ".by_position" do
      it "按位置筛选" do
        home_banner = create(:banner, position: 1)
        detail_banner = create(:banner, position: 2)

        expect(Banner.by_position(1)).to include(home_banner)
        expect(Banner.by_position(1)).not_to include(detail_banner)
      end
    end
  end
end
