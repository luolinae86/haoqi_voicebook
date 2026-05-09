# frozen_string_literal: true

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
end
