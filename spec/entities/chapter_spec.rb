# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Entities::Chapter', type: :model do
  describe 'publish_date' do
    it 'returns publish_date in chapter entity' do
      book = create(:book)
      create(:chapter, book: book, publish_date: Date.new(2026, 5, 25))

      chapter = book.chapters.first
      result = Entities::Chapter.represent(chapter).as_json

      expect(result).to have_key(:publish_date)
      expect(result[:publish_date]).to eq(Date.new(2026, 5, 25))
    end

    it 'returns nil for publish_date when not set' do
      book = create(:book)
      create(:chapter, book: book, publish_date: nil)

      chapter = book.chapters.first
      result = Entities::Chapter.represent(chapter).as_json

      expect(result).to have_key(:publish_date)
      expect(result[:publish_date]).to be_nil
    end
  end

  describe 'file path fields' do
    let(:book) { create(:book) }

    it 'does not return ld_file_path, hd_file_path, sd_file_path' do
      create(:chapter,
             book: book,
             ld_file_path: 'https://cdn.example.com/ld/video.mp4',
             hd_file_path: 'https://cdn.example.com/hd/video.mp4',
             sd_file_path: 'https://cdn.example.com/sd/video.mp4')

      chapter = book.chapters.first
      result = Entities::Chapter.represent(chapter).as_json

      expect(result).not_to have_key(:ld_file_path)
      expect(result).not_to have_key(:hd_file_path)
      expect(result).not_to have_key(:sd_file_path)
    end
  end
end
