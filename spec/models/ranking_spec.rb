# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ranking, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to have_many(:ranking_items).dependent(:destroy) }
    it { is_expected.to have_many(:books).through(:ranking_items) }
  end

  # 验证测试
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:ranking_type) }
  end

  # 枚举测试
  describe "enums" do
    it { is_expected.to define_enum_for(:ranking_type).with_values(hot: 0, high_score: 1, new_arrival: 2, award: 3, classic: 4) }
  end
end
