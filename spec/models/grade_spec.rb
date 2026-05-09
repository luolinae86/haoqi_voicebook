# frozen_string_literal: true

require "rails_helper"

RSpec.describe Grade, type: :model do
  describe "associations" do
    it { is_expected.to have_and_belong_to_many(:compilations) }
    it { is_expected.to have_and_belong_to_many(:books) }
    it { is_expected.to have_many(:recommends).dependent(:destroy) }
  end
end
