# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GetuiService do
  before do
    allow(Getui).to receive(:push_single).and_return({ 'result' => 'ok' })
    allow(Getui).to receive(:save_list_body).and_return('task_123')
    allow(Getui).to receive(:push_list).and_return({ 'result' => 'ok' })
    allow(Getui).to receive(:push_app).and_return({ 'result' => 'ok' })
  end

  describe '#push_to_single' do
    it 'sends a push to a single cid' do
      service = GetuiService.new
      result = service.push_to_single('cid_123', 'Title', 'Body')

      expect(result).to eq({ 'result' => 'ok' })
      expect(Getui).to have_received(:push_single).with(
        'cid_123',
        kind_of(Getui::Message::Transmission)
      )
    end

    it 'raises error when cid is blank' do
      service = GetuiService.new
      expect { service.push_to_single('', 'Title', 'Body') }.to raise_error(ArgumentError, 'cid 不能为空')
    end

    it 'raises PushError on API failure' do
      allow(Getui).to receive(:push_single).and_raise(Getui::PushError, 'invalid cid')
      service = GetuiService.new
      expect { service.push_to_single('cid_123', 'Title', 'Body') }.to raise_error(GetuiService::PushError)
    end
  end

  describe '#push_to_batch' do
    it 'returns empty hash for empty cid list' do
      service = GetuiService.new
      expect(service.push_to_batch([], 'Title', 'Body')).to eq({})
    end

    it 'returns empty hash for nil cid list' do
      service = GetuiService.new
      expect(service.push_to_batch(nil, 'Title', 'Body')).to eq({})
    end

    it 'calls save_list_body then push_list' do
      service = GetuiService.new
      service.push_to_batch(%w[cid_1 cid_2], 'Title', 'Body')

      expect(Getui).to have_received(:save_list_body)
      expect(Getui).to have_received(:push_list).with(%w[cid_1 cid_2], 'task_123')
    end
  end

  describe '#push_to_all' do
    it 'sends a push to all users' do
      service = GetuiService.new
      result = service.push_to_all('Title', 'Body')

      expect(result).to eq({ 'result' => 'ok' })
      expect(Getui).to have_received(:push_app)
    end

    it 'raises PushError on API failure' do
      allow(Getui).to receive(:push_app).and_raise(Getui::PushError, 'app not found')
      service = GetuiService.new
      expect { service.push_to_all('Title', 'Body') }.to raise_error(GetuiService::PushError)
    end
  end
end
