# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PushNotificationWorker, type: :job do
  describe '#perform' do
    before do
      allow_any_instance_of(GetuiService).to receive(:push_to_single).and_return({ 'result' => 'ok' })
      allow_any_instance_of(GetuiService).to receive(:push_to_batch).and_return({ 'result' => 'ok' })
      allow_any_instance_of(GetuiService).to receive(:push_to_all).and_return({ 'result' => 'ok' })
      Sidekiq::Queues.clear_all
    end

    context 'with single push' do
      it 'enqueues and performs a single push' do
        Sidekiq::Testing.inline! do
          PushNotificationWorker.perform_async({
                                                 'cid' => 'test_cid_123',
                                                 'title' => 'Test Title',
                                                 'body' => 'Test Body'
                                               })
        end

        expect(Sidekiq::Queues['push'].size).to eq(0) # processed inline
      end

      it 'raises error when title is blank' do
        expect do
          PushNotificationWorker.new.perform({ 'cid' => 'cid1', 'title' => '', 'body' => 'hello' })
        end.to raise_error(ArgumentError, 'title 不能为空')
      end

      it 'raises error when body is blank' do
        expect do
          PushNotificationWorker.new.perform({ 'cid' => 'cid1', 'title' => 'hello', 'body' => '' })
        end.to raise_error(ArgumentError, 'body 不能为空')
      end

      it 'raises error when no target specified' do
        expect do
          PushNotificationWorker.new.perform({ 'title' => 'hello', 'body' => 'world' })
        end.to raise_error(ArgumentError, '必须指定 cid、cid_list 或 all 之一')
      end
    end

    context 'with batch push' do
      it 'enqueues a batch push job to the push queue' do
        PushNotificationWorker.perform_async({
                                               'cid_list' => %w[cid1 cid2],
                                               'title' => 'Batch Title',
                                               'body' => 'Batch Body'
                                             })

        job = Sidekiq::Queues['push'].find { |j| j['class'] == 'PushNotificationWorker' }
        expect(job).to be_present
        expect(job['args'].first['cid_list']).to eq(%w[cid1 cid2])
      end
    end

    context 'with all push' do
      it 'enqueues an all push job to the push queue' do
        PushNotificationWorker.perform_async({
                                               'all' => true,
                                               'title' => 'All Title',
                                               'body' => 'All Body'
                                             })

        job = Sidekiq::Queues['push'].find { |j| j['class'] == 'PushNotificationWorker' }
        expect(job).to be_present
        expect(job['args'].first['all']).to be true
      end
    end

    context 'with payload' do
      it 'enqueues a job with payload' do
        PushNotificationWorker.perform_async({
                                               'cid' => 'cid1',
                                               'title' => 'Title',
                                               'body' => 'Body',
                                               'payload' => { 'book_id' => 14, 'type' => 'new_book' }
                                             })

        job = Sidekiq::Queues['push'].find { |j| j['class'] == 'PushNotificationWorker' }
        expect(job).to be_present
        expect(job['args'].first['payload']).to eq({ 'book_id' => 14, 'type' => 'new_book' })
      end
    end
  end
end
