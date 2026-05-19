# frozen_string_literal: true

# == Schema Information
#
# Table name: head_imgs
#
#  id         :bigint           not null, primary key
#  img_url    :string(255)
#  is_vip     :boolean          default(FALSE)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "rails_helper"

RSpec.describe HeadImg, type: :model do
  describe "scopes" do
    it "vip scope returns only VIP images" do
      vip_img = create(:head_img, is_vip: true)
      create(:head_img, is_vip: false)
      expect(HeadImg.vip).to include(vip_img)
      expect(HeadImg.vip.count).to eq(1)
    end

    it "normal scope returns only non-VIP images" do
      create(:head_img, is_vip: true)
      normal_img = create(:head_img, is_vip: false)
      expect(HeadImg.normal).to include(normal_img)
      expect(HeadImg.normal.count).to eq(1)
    end
  end

  describe ".random_for" do
    it "returns a random VIP image when vip: true" do
      vip_img = create(:head_img, is_vip: true)
      result = HeadImg.random_for(vip: true)
      expect(result).to be_present
      expect(result.is_vip).to eq(true)
    end

    it "returns a random non-VIP image when vip: false" do
      normal_img = create(:head_img, is_vip: false)
      result = HeadImg.random_for(vip: false)
      expect(result).to be_present
      expect(result.is_vip).to eq(false)
    end

    it "returns nil when no matching images exist" do
      expect(HeadImg.random_for(vip: true)).to be_nil
    end
  end
end
