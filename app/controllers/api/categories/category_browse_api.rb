# frozen_string_literal: true

module Api
  module Categories
    class CategoryBrowseApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Categories::CategoryBrowseHelpers

      namespace :categories do
        before do
          auth_user
        end

        # ==================== 接口：分类浏览（按年级+内容类型+一级分类+二级分类筛选） ====================
        desc '分类浏览：按年级、内容类型、分类筛选图书和合集，按热度排序'
        params do
          optional :grade_id, type: Integer, desc: '年级ID'
          optional :content_type, type: String, values: %w[ebook audio video picture_book], desc: '内容类型'
          optional :category_id, type: Integer, desc: '一级分类ID'
          optional :category_sub_id, type: Integer, desc: '二级分类ID'
          optional :page, type: Integer, default: 1, desc: '页码'
          optional :per_page, type: Integer, default: 20, desc: '每页数量'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'browse' do
          content_type = params[:content_type]
          category_id = params[:category_id]
          category_sub_id = params[:category_sub_id]
          grade_id = params[:grade_id]
          page = [params[:page].to_i, 1].max
          per_page = [params[:per_page].to_i, 100].min

          books = find_books(grade_id, content_type, category_id, category_sub_id)
          compilations = find_compilations(grade_id, content_type, category_id, category_sub_id)

          merged = merge_and_sort(books, compilations)
          paginated = paginate_collection(merged, page, per_page)

          present response: success_response(
            books: paginated[:books].map { |b| serialize_book_for_browse(b) },
            compilations: paginated[:compilations].map { |c| serialize_compilation_for_browse(c) },
            pagination: {
              page: page,
              per_page: per_page,
              total: paginated[:total]
            }
          )
        end

        # ==================== 接口：获取指定一级分类下的二级分类列表 ====================
        desc '获取二级分类列表（用于左侧筛选栏）'
        params do
          optional :grade_id, type: Integer, desc: '年级ID（可选，用于筛选该年级下有关联的二级分类）'
          optional :category_id, type: Integer, desc: '一级分类ID'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'subs' do
          category_subs = find_category_subs(params[:grade_id], params[:category_id])
          present response: success_response(
            category_subs: category_subs.map { |cs| { id: cs.id, name: cs.name, sn: cs.sn } }
          )
        end
      end
    end
  end
end
