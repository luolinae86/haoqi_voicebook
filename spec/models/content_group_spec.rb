# frozen_string_literal: true

# == Schema Information
#
# Table name: content_groups
#
#  id                     :bigint           not null, primary key
#  group_type(小组类型)   :string(255)      not null
#  name(小组名称)         :string(255)      not null
#  sn(排序)               :integer          default(0)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  recommend_id(关联年级) :bigint           not null
#
# Indexes
#
#  index_content_groups_on_recommend_id  (recommend_id)
#
# Foreign Keys
#
#  fk_rails_...  (recommend_id => recommends.id)
#
require "rails_helper"

RSpec.describe ContentGroup, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:recommend) }
    it { is_expected.to have_many(:contents).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:group_type) }
  end

  describe "enums" do
    it "定义了 group_type 枚举" do
      expect(ContentGroup.group_types).to include("multi_images", "one_row_three_columns", "one_row_display")
    end
  end
end
