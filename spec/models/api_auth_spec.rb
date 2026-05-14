# frozen_string_literal: true

# == Schema Information
#
# Table name: api_auths(API认证表)
#
#  id                            :bigint           not null, primary key
#  access_key_secret(客户端密钥) :string(255)      not null
#  name(客户端名称)              :string(255)      not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  access_key_id(客户端ID)       :string(255)      not null
#
# Indexes
#
#  index_api_auths_on_access_key_id  (access_key_id) UNIQUE
#
require "rails_helper"

RSpec.describe ApiAuth, type: :model do
  # 验证测试
  describe "validations" do
    subject { create(:api_auth) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:access_key_id) }
    it { is_expected.to validate_uniqueness_of(:access_key_id).case_insensitive }
    it { is_expected.to validate_presence_of(:access_key_secret) }
  end

  # 回调测试
  describe "callbacks" do
    describe "before_create" do
      it "自动生成 access_key_id" do
        api_auth = build(:api_auth, access_key_id: nil, access_key_secret: nil)
        api_auth.send(:generate_keys)
        expect(api_auth.access_key_id).to be_present
        expect(api_auth.access_key_id.length).to eq(32)
      end

      it "自动生成 access_key_secret" do
        api_auth = build(:api_auth, access_key_id: nil, access_key_secret: nil)
        api_auth.send(:generate_keys)
        expect(api_auth.access_key_secret).to be_present
        expect(api_auth.access_key_secret.length).to eq(64)
      end

      it "不覆盖已有的 access_key_id" do
        api_auth = build(:api_auth, access_key_id: "custom_key")
        api_auth.send(:generate_keys)
        expect(api_auth.access_key_id).to eq("custom_key")
      end
    end
  end
end
