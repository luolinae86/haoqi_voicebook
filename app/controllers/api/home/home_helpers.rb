# frozen_string_literal: true

module Api
  module Home
    module HomeHelpers
      extend Grape::API::Helpers
      include Api::Oss::OssHelpers

      def home_recommend_detail(recommend)
        recommend.content_groups.includes(:contents).map { |cg| serialize_content_group(cg) }
      end

      def home_recommends_for_grade(grade_id)
        Recommend.by_grade(grade_id).published.includes(content_groups: :contents).map do |recommend|
          {
            id: recommend.id,
            name: recommend.name,
            content_groups: recommend.content_groups.map { |cg| serialize_content_group(cg) }
          }
        end
      end

      private

      def book_blacklisted?(book_id)
        return false if book_id.blank?

        pc = current_user&.parental_control
        return false unless pc

        pc.blacklisted_books.exists?(book_id: book_id)
      rescue StandardError
        false
      end

      def serialize_content_group(cg)
        {
          id: cg.id,
          name: cg.name,
          group_type: cg.group_type,
          group_type_name: cg.group_type_name,
          contents: cg.contents.includes(:book, :category_sub).sorted.reject { |c| book_blacklisted?(c.book_id) }.map { |content| serialize_content(content) }
        }
      end

      def serialize_content(content)
        display_name = content.name.presence || content.book&.name || content.compilation&.name || content.category_sub&.name || ''
        content_hash = {
          id: content.id,
          content_type: content.content_type,
          content_type_name: content.content_type_name,
          sn: content.sn,
          name: display_name,
          color: content.color
        }

        case content.content_type
        when 'compilation'
          content_hash[:compilation] = serialize_compilation(content.compilation) if content.compilation
        when 'book'
          content_hash[:book] = serialize_book(content.book) if content.book
        when 'author_display'
          content_hash[:author] = serialize_author(content.author) if content.author
        when 'recommend'
          content_hash[:recommend] = serialize_sub_recommend(content.recommend) if content.recommend
        when 'category_sub'
          content_hash[:category_sub] = serialize_category_sub(content.category_sub) if content.category_sub
        end

        content_hash[:img_url] = signed_oss_url(content.img_url) if content.img_url.present?

        content_hash
      end

      def serialize_compilation(compilation)
        {
          id: compilation.id,
          name: compilation.name,
          cover_url: signed_oss_url(compilation.banner_image_url),
          editor_recommendation: compilation.editor_recommendation,
          total_count: compilation.total_count,
          author: compilation.author,
          publisher: compilation.publisher,
          description: compilation.description
        }
      end

      def serialize_book(book)
        {
          id: book.id,
          name: book.name,
          cover_url: signed_oss_url(book.cover_image_url),
          category_id: book.category_id,
          category_name: book.category&.name,
          content_description: book.content_description,
          supplier_name: book.supplier&.name,
          category_subs: book.category_subs.map { |cs| { id: cs.id, name: cs.name, sn: cs.sn } },
          is_free: book.is_free
        }
      end

      def serialize_author(author)
        {
          id: author.id,
          name: author.name,
          head_img: signed_oss_url(author.head_img)
        }
      end

      def serialize_sub_recommend(recommend)
        {
          id: recommend.id,
          name: recommend.name,
          sn: recommend.sn,
          color: recommend.color || '',
          status_text: recommend.status_text
        }
      end

      def serialize_category_sub(category_sub)
        {
          id: category_sub.id,
          name: category_sub.name,
          icon: signed_oss_url(category_sub.icon),
          category_id: category_sub.category_id,
          sn: category_sub.sn
        }
      end
    end
  end
end
