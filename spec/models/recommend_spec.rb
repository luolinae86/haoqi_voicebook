# frozen_string_literal: true

# == Schema Information
#
# Table name: recommends
#
#  id                               :bigint           not null, primary key
#  name(推荐内容名称)               :string(255)      not null
#  sn(排序)                         :integer          default(0)
#  status(状态: true发布/false草稿) :boolean          default(TRUE)
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  grade_id(关联年级)               :bigint           not null
#
# Indexes
#
#  index_recommends_on_grade_id         (grade_id)
#  index_recommends_on_grade_id_and_sn  (grade_id,sn)
#
# Foreign Keys
#
#  fk_rails_...  (grade_id => grades.id)
#
require "rails_helper"

RSpec.describe Recommend, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:grade) }
    it { is_expected.to have_many(:content_groups).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(10) }
    it { is_expected.to validate_presence_of(:grade_id) }
  end

  describe "scopes" do
    let!(:grade1) { create(:grade, name: "一年级") }
    let!(:grade2) { create(:grade, name: "二年级") }
    let!(:published_recs) do
      [
        Recommend.create!(grade: grade1, name: "文学", status: true, sn: 0),
        Recommend.create!(grade: grade1, name: "图书", status: true, sn: 1)
      ]
    end
    let!(:draft_rec) { Recommend.create!(grade: grade1, name: "草稿", status: false, sn: 2) }
    let!(:other_grade_rec) { Recommend.create!(grade: grade2, name: "其他", status: true, sn: 0) }

    describe ".published" do
      it "只返回已发布的推荐" do
        results = Recommend.published
        expect(results).to match_array(published_recs + [other_grade_rec])
      end

      it "不包含草稿状态的推荐" do
        expect(Recommend.published).not_to include(draft_rec)
      end
    end

    describe ".by_grade" do
      it "返回指定年级的推荐" do
        results = Recommend.by_grade(grade1.id)
        expect(results).to match_array(published_recs + [draft_rec])
      end

      it "不包含其他年级的推荐" do
        expect(Recommend.by_grade(grade1.id)).not_to include(other_grade_rec)
      end
    end

    describe ".by_grade.published（链式调用）" do
      it "返回指定年级且已发布的推荐" do
        results = Recommend.by_grade(grade1.id).published
        expect(results).to match_array(published_recs)
      end

      it "不包含草稿状态和其他年级的推荐" do
        results = Recommend.by_grade(grade1.id).published
        expect(results).not_to include(draft_rec)
        expect(results).not_to include(other_grade_rec)
      end
    end
  end
end
