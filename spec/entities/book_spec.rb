# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Entities::Book do
  let(:book) { create(:book) }

  subject(:json) { described_class.represent(book).as_json }

  it 'returns chapters as empty array when no chapters exist' do
    expect(json[:chapters]).to eq([])
  end

  it 'returns chapters with signed URLs when chapters exist' do
    create(:chapter, book: book, name: '第一章', sn: 1, content_file_type: 'mp3')
    create(:chapter, book: book, name: '第二章', sn: 2, content_file_type: 'mp4')

    refreshed_json = described_class.represent(book.reload).as_json
    expect(refreshed_json[:chapters].size).to eq(2)
    expect(refreshed_json[:chapters][0][:name]).to eq('第一章')
    expect(refreshed_json[:chapters][0][:content_file_type]).to eq('mp3')
    expect(refreshed_json[:chapters][0][:file_type_name]).to eq('有声')
    expect(refreshed_json[:chapters][1][:name]).to eq('第二章')
    expect(refreshed_json[:chapters][1][:content_file_type]).to eq('mp4')
    expect(refreshed_json[:chapters][1][:file_type_name]).to eq('视频')
  end

  it 'orders chapters by sn' do
    create(:chapter, book: book, name: '第二章', sn: 2)
    create(:chapter, book: book, name: '第一章', sn: 1)

    refreshed_json = described_class.represent(book.reload).as_json
    expect(refreshed_json[:chapters].map { |c| c[:name] }).to eq(['第一章', '第二章'])
  end
end
