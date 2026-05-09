# frozen_string_literal: true

require "rails_helper"

RSpec.describe Compilation, type: :model do
  describe "associations" do
    it { is_expected.to have_and_belong_to_many(:grades) }
    it { is_expected.to have_and_belong_to_many(:categories) }
    it { is_expected.to have_and_belong_to_many(:books) }
    it { is_expected.to have_many(:contents) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe "实例方法" do
    describe "#covers_complete?" do
      it "当三个封面都存在时返回 true" do
        compilation = Compilation.new(
          name: "Test",
          landscape_cover_url: "http://example.com/l.jpg",
          portrait_cover_url: "http://example.com/p.jpg",
          square_cover_url: "http://example.com/s.jpg"
        )
        expect(compilation.covers_complete?).to be true
      end

      it "当缺少封面时返回 false" do
        compilation = Compilation.new(name: "Test", landscape_cover_url: nil)
        expect(compilation.covers_complete?).to be false
      end
    end

    describe "#main_cover_url" do
      it "优先返回 landscape_cover_url" do
        compilation = Compilation.new(
          name: "Test",
          landscape_cover_url: "http://example.com/l.jpg",
          banner_image_url: "http://example.com/b.jpg"
        )
        expect(compilation.main_cover_url).to eq("http://example.com/l.jpg")
      end

      it "没有 landscape 时返回 banner_image_url" do
        compilation = Compilation.new(
          name: "Test",
          landscape_cover_url: nil,
          banner_image_url: "http://example.com/b.jpg"
        )
        expect(compilation.main_cover_url).to eq("http://example.com/b.jpg")
      end
    end
  end
end
