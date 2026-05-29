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

      def serialize_content_group(cg)
        {
          id: cg.id,
          name: cg.name,
          group_type: cg.group_type,
          group_type_name: cg.group_type_name,
          contents: cg.contents.sorted.map { |content| serialize_content(content) }
        }
      end

      def serialize_content(content)
        content_hash = {
          id: content.id,
          content_type: content.content_type,
          content_type_name: content.content_type_name,
          sn: content.sn
        }

        case content.content_type
        when "compilation"
          content_hash[:compilation] = serialize_compilation(content.compilation) if content.compilation
        when "book"
          content_hash[:book] = serialize_book(content.book) if content.book
        when "author_display"
          content_hash[:author] = serialize_author(content.author) if content.author
        when "recommend"
          content_hash[:recommend] = serialize_sub_recommend(content.recommend) if content.recommend
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
          supplier_name: book.supplier&.name,
          category_subs: book.category_subs.map { |cs| { id: cs.id, name: cs.name, sn: cs.sn } }
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
          color: recommend.try(:color) || "",
          status_text: recommend.status_text
        }
      end
    end
  end
end
