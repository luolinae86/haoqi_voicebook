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

            success_response(categories.map { |cat|
              {
                id: cat.id,
                name: cat.name,
                icon: cat.icon,
                description: cat.description,
                children_count: cat.children.count
              }
            })
          end

          # ==================== 分类详情（含子分类） ====================
          desc "获取分类详情"
          params do
            requires :id, type: Integer, desc: "分类ID"
          end
          get ":id" do
            category = Category.find(params[:id])

            success_response({
              id: category.id,
              name: category.name,
              icon: category.icon,
              description: category.description,
              children: category.children.ordered.map { |child|
                { id: child.id, name: child.name, icon: child.icon }
              }
            })
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

            paginated_response(books.recently_added)
          end
        end

        # ==================== 年级列表 ====================
        namespace :grades do
          desc "获取年级列表"
          get do
            grades = Grade.ordered
            success_response(grades.map { |g|
              { id: g.id, name: g.name, level: g.level, description: g.description }
            })
          end
        end
      end
    end
  end
end
