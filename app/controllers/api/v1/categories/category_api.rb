# frozen_string_literal: true

# 分类接口
# 提供分类列表、分类下的图书等功能
module Api
  module V1
    module Categories
      class CategoryApi < Grape::API
        helpers Api::Helpers::CommonHelpers

        namespace :categories do
          # ==================== 分类列表 ====================
          desc "获取分类列表"
          params do
            optional :parent_id, type: Integer, desc: "父分类ID（不传则返回顶级分类）"
          end
          get do
            categories = if params[:parent_id].present?
                           Category.where(parent_id: params[:parent_id]).ordered
                         else
                           Category.roots.ordered
                         end

            present response: success_response, categories: serialize_collection(categories, Entities::Category)
          end

          # ==================== 分类详情（含子分类） ====================
          desc "获取分类详情"
          params do
            requires :id, type: Integer, desc: "分类ID"
          end
          get ":id" do
            category = Category.find(params[:id])

            present response: success_response, category: (present category, with: Entities::CategoryDetail)
          end

          # ==================== 分类下的图书 ====================
          desc "获取分类下的图书列表"
          params do
            requires :id, type: Integer, desc: "分类ID"
            optional :content_type, type: String, desc: "内容类型"
            optional :page, type: Integer, desc: "页码", default: 1
            optional :per_page, type: Integer, desc: "每页数量", default: 10
          end
          get ":id/books" do
            books = Book.published_books.by_category(params[:id])
            books = books.by_type(params[:content_type]) if params[:content_type].present?

            paged = books.recently_added.page(params[:page] || 1).per(params[:per_page] || 10)
            present response: success_response, data: paged, pagination: {
              current_page: paged.current_page,
              total_pages: paged.total_pages,
              total_count: paged.total_count,
              per_page: (params[:per_page] || 10).to_i
            }
          end
        end

        # ==================== 年级列表 ====================
        namespace :grades do
          desc "获取年级列表"
          get do
            grades = Grade.ordered
            present response: success_response, grades: serialize_collection(grades, Entities::Grade)
          end
        end

        helpers do
          def serialize_collection(collection, entity_class, **options)
            collection.map { |item| entity_class.represent(item, options).as_json }
          end
        end
      end
    end
  end
end
