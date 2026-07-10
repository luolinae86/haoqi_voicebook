# frozen_string_literal: true

module Api
  module Home
    class HomeApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Home::HomeHelpers

      namespace :home do
        desc '获取首页推荐列表（仅 recommends 层级）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get :recommends do
          auth_user

          recommends = if current_user.grade_id.present?
                         Recommend.by_grade(current_user.grade_id).published
                       else
                         []
                       end

          present response: success_response(recommends: serialize_collection(recommends, Entities::Recommend))
        end

        desc '获取指定推荐的详细内容（含 content_groups 和 contents）'
        params do
          requires :recommend_id, type: Integer, desc: '推荐ID'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'recommends/by_recommend_id' do
          auth_user

          recommend = Recommend.find_by(id: params[:recommend_id], grade_id: current_user.grade_id)
          return present response: success_response(content_groups: []) unless recommend

          # 缓存键：包含 recommend.updated_at，内容变更时通过 touch 链自动失效
          cache_key = "home_recommend_detail_#{recommend.id}_#{recommend.updated_at.to_i}"

          content_groups = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
            # 深层预加载：避免 N+1
            cgs = recommend.content_groups
              .includes(contents: [:compilation, :author, :recommend,
                                   { book: [:category, :supplier, :category_subs] },
                                   :category_sub])
              .sorted

            cgs.map do |cg|
              {
                id: cg.id,
                name: cg.name,
                group_type: cg.group_type,
                group_type_name: cg.group_type_name,
                contents: cg.contents.sorted.map { |c| serialize_content(c) }
              }
            end
          end

          # 对缓存结果应用用户维度的黑名单过滤（轻量操作，不做缓存）
          content_groups = filter_blacklisted(content_groups)

          present response: success_response(content_groups: content_groups)
        end
      end
    end
  end
end