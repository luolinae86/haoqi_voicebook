# frozen_string_literal: true

module Api
  module Categories
    module CategoryBrowseHelpers
      extend Grape::API::Helpers
      include Api::Oss::OssHelpers

      # 查询图书：按 grade_id + content_type + category_id + category_sub_id 筛选，按热度排序
      def find_books(grade_id, content_type, category_id, category_sub_id)
        scope = Book
        scope = scope.joins(:grades).where(grades: { id: grade_id }) if grade_id.present?
        scope = scope.where(content_type: content_type) if content_type.present?
        scope = scope.where(category_id: category_id) if category_id.present?
        scope = scope.joins(:category_subs).where(category_subs: { id: category_sub_id }) if category_sub_id.present?
        scope.distinct.order(play_count: :desc, id: :desc)
      end

      # 查询合集：按 grade_id + content_type（间接）+ category_id + category_sub_id（间接）筛选
      def find_compilations(grade_id, content_type, category_id, category_sub_id)
        scope = Compilation
        scope = scope.joins(:grades).where(grades: { id: grade_id }) if grade_id.present?

        # content_type 筛选：合集没有 content_type，但可以通过内容类型过滤
        if content_type.present?
          scope = scope.where("EXISTS (
            SELECT 1 FROM compilation_books cb
            JOIN books b ON b.id = cb.book_id
            WHERE cb.compilation_id = compilations.id AND b.content_type = ?
          )", content_type)
        end

        # category_id 筛选：合集通过 compilation_categories 关联一级分类
        scope = scope.joins(:categories).where(categories: { id: category_id }) if category_id.present?

        # category_sub_id 筛选：合集没有直接的 category_sub 关联，但可以通过二级分类关联的一级分类
        if category_sub_id.present?
          category_sub = CategorySub.find_by(id: category_sub_id)
          scope = scope.joins(:categories).where(categories: { id: category_sub.category_id }) if category_sub
        end

        scope.distinct.order(created_at: :desc, id: :desc)
      end

      # 合并图书和合集，按 play_count 排序（合集无 play_count 用 0）
      def merge_and_sort(books, compilations)
        book_items = books.map { |b| { type: 'book', id: b.id, play_count: b.play_count.to_i } }
        comp_items = compilations.map { |c| { type: 'compilation', id: c.id, play_count: 0 } }
        sorted = (book_items + comp_items).sort_by { |item| -item[:play_count] }
        { sorted: sorted, books: books, compilations: compilations }
      end

      # 分页合并后的结果
      def paginate_collection(result, page, per_page)
        all = result[:sorted]
        total = all.size
        start = (page - 1) * per_page
        page_items = all[start, per_page] || []

        page_book_ids = page_items.select { |i| i[:type] == 'book' }.map { |i| i[:id] }
        page_comp_ids = page_items.select { |i| i[:type] == 'compilation' }.map { |i| i[:id] }

        books = result[:books].to_a.select { |b| page_book_ids.include?(b.id) }
        compilations = result[:compilations].to_a.select { |c| page_comp_ids.include?(c.id) }

        # 按 page_items 的顺序重新排序
        ordered_books = page_book_ids.map { |id| books.find { |b| b.id == id } }.compact
        ordered_comps = page_comp_ids.map { |id| compilations.find { |c| c.id == id } }.compact

        { books: ordered_books, compilations: ordered_comps, total: total }
      end

      # 查询二级分类：根据 grade_id 和 category_id 筛选
      def find_category_subs(grade_id, category_id)
        scope = CategorySub

        scope = scope.where(category_id: category_id) if category_id.present?

        if grade_id.present?
          # 只返回该年级下有内容关联的二级分类
          scope = scope.joins(:books).where(books: { id: Book.joins(:grades).where(grades: { id: grade_id }) })
        end

        scope.distinct.sorted
      end

      # 序列化图书（分类浏览场景）
      def serialize_book_for_browse(book)
        {
          id: book.id,
          name: book.name,
          cover_url: Book.sign_oss_url(book.cover_image_url),
          category_id: book.category_id,
          author_name: book.author ? "#{book.author.name}【著】" : nil,
          supplier_name: book.supplier&.name,
          publisher: book.supplier&.name,
          description: book.content_description&.to_s&.truncate(50),
          content_type: book.content_type,
          play_count: book.play_count,
          word_count: book.word_count,
          page_count: book.page_count,
          rating: book.rating,
          content_description: book.content_description,
          category_subs: book.category_subs.map { |cs| { id: cs.id, name: cs.name, sn: cs.sn } },
          is_free: book.is_free
        }
      end

      # 序列化合集（分类浏览场景）
      def serialize_compilation_for_browse(compilation)
        {
          id: compilation.id,
          name: compilation.name,
          cover_url: signed_oss_url(compilation.banner_image_url),
          category_id: compilation.categories.map(&:id).first,
          editor_recommendation: compilation.editor_recommendation,
          publisher: compilation.publisher,
          total_count: compilation.total_count,
          author: compilation.author,
          tags: compilation.tags,
          content_description: compilation.description
        }
      end

      private

      def signed_oss_url(url)
        return nil if url.blank?

        Book.sign_oss_url(url)
      end
    end
  end
end
