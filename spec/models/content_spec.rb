# frozen_string_literal: true

require "rails_helper"

RSpec.describe Content, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:content_group) }
    it { is_expected.to belong_to(:compilation).optional }
    it { is_expected.to belong_to(:book).optional }
    it { is_expected.to belong_to(:author).optional }
  end
end
