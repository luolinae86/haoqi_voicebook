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

    it 'returns ld_file_path, hd_file_path, sd_file_path' do
      create(:chapter,
             book: book,
             ld_file_path: 'https://cdn.example.com/ld/video.mp4',
             hd_file_path: 'https://cdn.example.com/hd/video.mp4',
             sd_file_path: 'https://cdn.example.com/sd/video.mp4')

      chapter = book.chapters.first
      result = Entities::Chapter.represent(chapter).as_json

      expect(result[:ld_file_path]).to eq('https://cdn.example.com/ld/video.mp4')
      expect(result[:hd_file_path]).to eq('https://cdn.example.com/hd/video.mp4')
      expect(result[:sd_file_path]).to eq('https://cdn.example.com/sd/video.mp4')
    end

    it 'returns nil for file path fields when not set' do
      create(:chapter, book: book)

      chapter = book.chapters.first
      result = Entities::Chapter.represent(chapter).as_json

      expect(result[:ld_file_path]).to be_nil
      expect(result[:hd_file_path]).to be_nil
      expect(result[:sd_file_path]).to be_nil
    end

    it 'signs aliyuncs.com OSS URLs for file path fields' do
      create(:chapter,
             book: book,
             ld_file_path: 'https://voicebook.oss-cn-hangzhou.aliyuncs.com/ld/video.mp4',
             hd_file_path: 'https://voicebook.oss-cn-hangzhou.aliyuncs.com/hd/video.mp4',
             sd_file_path: 'https://voicebook.oss-cn-hangzhou.aliyuncs.com/sd/video.mp4')

      chapter = book.chapters.first
      result = Entities::Chapter.represent(chapter).as_json

      expect(result[:ld_file_path]).to include('voicebook.oss-cn-hangzhou.aliyuncs.com')
      expect(result[:ld_file_path]).to include('Signature=')
      expect(result[:hd_file_path]).to include('Signature=')
      expect(result[:sd_file_path]).to include('Signature=')
    end
  end
end
