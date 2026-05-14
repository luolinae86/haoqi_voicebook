# frozen_string_literal: true

# == Schema Information
#
# Table name: authors
#
#  id             :bigint           not null, primary key
#  head_img(头像) :string(255)      not null
#  name(作者名)   :string(255)      not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
require "rails_helper"

RSpec.describe Author, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:books) }
    it { is_expected.to have_many(:contents) }
  end
end
