# frozen_string_literal: true

# 首页接口
# 提供首页推荐、轮播图、分级阅读等数据
module Api
  module V1
    module Home
      class HomeApi < Grape::API
        helpers Api::Helpers::CommonHelpers

        namespace :home do
          # ==================== 首页数据 ====================
          desc "获取首页数据（推荐、轮播图等）"
          params do
            optional :grade_id, type: Integer, desc: "年级ID"
          end
          get do
            # 轮播图
            banners = Banner.active.ordered.limit(5)

            # 推荐栏目
            recommendations = Recommendation.ordered
            recommendations = recommendations.where(target_grade_id: [params[:grade_id], nil]) if params[:grade_id].present?

            success_response({
              banners: banners.map { |b|
                { id: b.id, title: b.title, image_url: b.image_url, link_url: b.link_url, link_type: b.link_type }
              },
              recommendations: recommendations.limit(10).map { |rec|
                {
                  id: rec.id,
                  title: rec.title,
                  description: rec.description,
                  type: rec.recommendation_type,
                  books: rec.books.published_books.limit(6).map { |book|
                    { id: book.id, title: book.title, cover_image: book.cover_image, author: book.author }
                  }
                }
              }
            })
          end

          # ==================== 轮播图列表 ====================
          desc "获取轮播图列表"
          get :banners do
            banners = Banner.active.ordered

            success_response(banners.map { |b|
              { id: b.id, title: b.title, image_url: b.image_url, link_url: b.link_url, link_type: b.link_type }
            })
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

            success_response(recs.map { |rec|
              {
                id: rec.id,
                title: rec.title,
                description: rec.description,
                type: rec.recommendation_type,
                books: rec.books.published_books.limit(10).map { |book|
                  { id: book.id, title: book.title, cover_image: book.cover_image, author: book.author, content_type: book.content_type }
                }
              }
            })
          end

          # ==================== 分级阅读 ====================
          desc "获取分级阅读列表"
          get :reading_levels do
            levels = ReadingLevel.ordered

            success_response(levels.map { |level|
              { id: level.id, name: level.name, level: level.level, description: level.description }
            })
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
            collections = Collection.ordered
            collections = collections.where(target_grade_id: [params[:grade_id], nil]) if params[:grade_id].present?
            collections = collections.where(collection_type: params[:type]) if params[:type].present?

            paginated_response(collections)
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

            success_response({
              id: collection.id,
              title: collection.title,
              description: collection.description,
              cover_image: collection.cover_image,
              books: paged_books.map { |book|
                { id: book.id, title: book.title, cover_image: book.cover_image, author: book.author, content_type: book.content_type }
              },
              pagination: {
                current_page: paged_books.current_page,
                total_pages: paged_books.total_pages,
                total_count: paged_books.total_count
              }
            })
          end
        end
      end
    end
  end
end
