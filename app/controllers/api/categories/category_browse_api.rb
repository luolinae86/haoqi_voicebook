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

        # ==================== 接口：分类浏览（按年级+内容类型+二级分类筛选） ====================
        desc '分类浏览：按年级、内容类型、二级分类筛选图书和合集，按热度排序'
        params do
          requires :grade_id, type: Integer, desc: '年级ID'
          optional :content_type, type: String, values: %w[ebook audio video picture_book], desc: '内容类型（ebook=图书, audio=听书, video=课程）'
          optional :category_sub_id, type: Integer, desc: '二级分类ID'
          optional :page, type: Integer, default: 1, desc: '页码'
          optional :per_page, type: Integer, default: 20, desc: '每页数量'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'browse' do
          content_type = params[:content_type]
          category_sub_id = params[:category_sub_id]
          page = [params[:page].to_i, 1].max
          per_page = [params[:per_page].to_i, 100].min

          books = find_books(params[:grade_id], content_type, category_sub_id)
          compilations = find_compilations(params[:grade_id], content_type, category_sub_id)

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

        # ==================== 接口：获取指定年级和一级分类下的二级分类列表 ====================
        desc '获取二级分类列表（用于左侧筛选栏）'
        params do
          requires :grade_id, type: Integer, desc: '年级ID'
          optional :content_type, type: String, values: %w[ebook audio video picture_book], desc: '内容类型'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'subs' do
          category_subs = find_category_subs(params[:grade_id], params[:content_type])
          present response: success_response(
            category_subs: category_subs.map { |cs| { id: cs.id, name: cs.name, sn: cs.sn } }
          )
        end
      end
    end
  end
end
