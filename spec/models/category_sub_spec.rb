# frozen_string_literal: true

# == Schema Information
#
# Table name: category_subs
#
#  id                    :bigint           not null, primary key
#  icon(图标URL)         :string(255)
#  name(子类名称)        :string(255)      not null
#  sn(排序)              :integer          default(0)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  category_id(关联分类) :bigint           not null
#
# Indexes
#
#  index_category_subs_on_category_id  (category_id)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#
require "rails_helper"

RSpec.describe CategorySub, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:category) }
    it { is_expected.to have_and_belong_to_many(:books) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:category_id) }
  end

  describe "scopes" do
    describe ".sorted" do
      it "按 sn 升序排列" do
        category = create(:category)
        create(:category_sub, category: category, sn: 10, name: "后")
        first = create(:category_sub, category: category, sn: 1, name: "前")

        expect(CategorySub.sorted.first).to eq(first)
      end
    end
  end
end
