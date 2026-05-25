# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities::Chapter", type: :model do
  describe "publish_date" do
    it "returns publish_date in chapter entity" do
      book = create(:book)
      create(:chapter, book: book, publish_date: Date.new(2026, 5, 25))

      chapter = book.chapters.first
      result = Entities::Chapter.represent(chapter).as_json

      expect(result).to have_key(:publish_date)
      expect(result[:publish_date]).to eq(Date.new(2026, 5, 25))
    end

    it "returns nil for publish_date when not set" do
      book = create(:book)
      create(:chapter, book: book, publish_date: nil)

      chapter = book.chapters.first
      result = Entities::Chapter.represent(chapter).as_json

      expect(result).to have_key(:publish_date)
      expect(result[:publish_date]).to be_nil
    end
  end
end
