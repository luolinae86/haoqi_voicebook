# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Grades', type: :request do
  let(:user) { create(:app_user) }

  # ==================== 获取年级列表 ====================
  describe 'GET /api/grades' do
    it '返回所有年级列表' do
      create_list(:grade, 3)

      get '/api/grades', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:grades]).to be_an(Array)
      expect(json_response[:response][:data][:grades].size).to eq(3)
    end

    it '每个年级包含必要字段' do
      grade = create(:grade, name: '四年级', group_name: '小学', description: '小学四年级')

      get '/api/grades', params: { uuid: user.uuid }

      item = json_response[:response][:data][:grades].first
      expect(item[:id]).to eq(grade.id)
      expect(item[:name]).to eq('四年级')
      expect(item[:group_name]).to eq('小学')
      expect(item[:description]).to eq('小学四年级')
    end

    it '按学龄前 > 小学 > 初中 > 高中的组顺序返回' do
      create(:grade, name: '学龄前', group_name: '学龄前')
      create(:grade, name: '一年级', group_name: '小学')
      create(:grade, name: '初一', group_name: '初中')
      create(:grade, name: '高中', group_name: '高中')
      create(:grade, name: '二年级', group_name: '小学')

      get '/api/grades', params: { uuid: user.uuid }

      groups = json_response[:response][:data][:grades].map { |g| g[:group_name] }
      expect(groups).to eq(%w[学龄前 小学 小学 初中 高中])

      group_names = json_response[:response][:data][:grades].map { |g| g[:name] }
      expect(group_names).to include('学龄前', '一年级', '二年级', '初一', '高中')
    end

    it '没有年级时返回空数组' do
      get '/api/grades', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:grades]).to eq([])
    end

    it '未登录时返回未授权错误' do
      get '/api/grades'

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end
  end
end
