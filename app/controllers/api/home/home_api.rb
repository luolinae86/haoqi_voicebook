# frozen_string_literal: true

# 首页接口
# 提供首页推荐、轮播图、分级阅读等数据
module Api
  module Home
    class HomeApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Home::HomeHelpers

      namespace :home do
        # ==================== 首页数据 ====================
        desc "获取首页数据（推荐、轮播图等）"
        params do
          optional :grade_id, type: Integer, desc: "年级ID"
        end
        get do
          data = home_data(grade_id: params[:grade_id])

          present response: success_response, **data
        end

        # ==================== 轮播图列表 ====================
        desc "获取轮播图列表"
        get :banners do
          banners = active_banners

          present response: success_response, banners: serialize_collection(banners, Entities::Banner)
        end

        # ==================== 推荐栏目 ====================
        desc "获取推荐栏目列表"
        params do
          optional :grade_id, type: Integer, desc: "年级ID"
          optional :type, type: String, desc: "推荐类型"
        end
        get :recommendations do
          recs = Recommendation.ordered
          recs = recs.where(target_grade_id: [params[:grade_id], nil]) if params[:grade_id].present?
          recs = recs.where(recommendation_type: params[:type]) if params[:type].present?

          present response: success_response, recommendations: serialize_collection(recs, Entities::Recommendation)
        end

        # ==================== 分级阅读 ====================
        desc "获取分级阅读列表"
        get :reading_levels do
          levels = ReadingLevel.ordered

          present response: success_response, levels: serialize_collection(levels, Entities::ReadingLevel)
        end

        # ==================== 合集列表 ====================
        desc "获取合集列表"
        params do
          optional :grade_id, type: Integer, desc: "年级ID"
          optional :type, type: String, desc: "合集类型"
          optional :page, type: Integer, desc: "页码", default: 1
          optional :per_page, type: Integer, desc: "每页数量", default: 10
        end
        get :collections do
          collections = filter_collections(grade_id: params[:grade_id], type: params[:type])

          paged = collections.page(params[:page] || 1).per(params[:per_page] || 10)
          present response: success_response, data: paged, pagination: pagination_info(paged)
        end

        # ==================== 合集详情 ====================
        desc "获取合集详情及图书列表"
        params do
          requires :id, type: Integer, desc: "合集ID"
          optional :page, type: Integer, desc: "页码", default: 1
          optional :per_page, type: Integer, desc: "每页数量", default: 10
        end
        get "collections/:id" do
          collection = Collection.find(params[:id])
          books = collection.books.published_books

          paged_books = books.page(params[:page]).per(params[:per_page])

          present response: success_response,
                          collection: (present collection, with: Entities::Collection),
                          books: serialize_collection_books(paged_books),
                          pagination: {
                            current_page: paged_books.current_page,
                            total_pages: paged_books.total_pages,
                            total_count: paged_books.total_count
                          }
        end
      end
    end
  end
end
