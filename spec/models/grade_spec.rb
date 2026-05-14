# frozen_string_literal: true

# == Schema Information
#
# Table name: grades
#
#  id          :bigint           not null, primary key
#  description :string(32)
#  group_name  :string(8)
#  name        :string(16)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
require "rails_helper"

RSpec.describe Grade, type: :model do
  describe "associations" do
    it { is_expected.to have_and_belong_to_many(:compilations) }
    it { is_expected.to have_and_belong_to_many(:books) }
    it { is_expected.to have_many(:recommends).dependent(:destroy) }
  end
end
