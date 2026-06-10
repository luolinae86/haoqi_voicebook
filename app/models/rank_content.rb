# frozen_string_literal: true

# == Schema Information
#
# Table name: rank_contents
#
#  id             :bigint           not null, primary key
#  content_type   :string(255)      default("book"), not null
#  sn             :integer          default(0)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  book_id        :bigint
#  compilation_id :bigint
#  rank_id        :bigint           not null
#
# Indexes
#
#  index_rank_contents_on_book_id         (book_id)
#  index_rank_contents_on_compilation_id  (compilation_id)
#  index_rank_contents_on_rank_id         (rank_id)
#
class RankContent < ApplicationRecord
  belongs_to :rank
  belongs_to :compilation, optional: true
  belongs_to :book, optional: true

  enum :content_type, {
    compilation: 'compilation',
    book: 'book',
  }, prefix: true

  CONTENT_TYPES = {
    compilation: '合辑',
    book: '单本',
  }.freeze

  def content_type_name
    CONTENT_TYPES[content_type.to_sym] || content_type
  end

  def content_name
    if content_type == 'compilation'
      compilation&.name
    elsif content_type == 'book'
      book&.name
    end
  end
end
