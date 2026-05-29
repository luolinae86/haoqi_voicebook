# == Schema Information
#
# Table name: contents
#
#  id                             :bigint           not null, primary key
#  content_type(类型)             :string(255)      not null
#  img_url(图片链接)              :string(255)
#  sn(排序)                       :integer          default(0)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  author_id(作者信息)            :bigint
#  book_id(单本信息)              :bigint
#  compilation_id(合辑信息)       :bigint
#  content_group_id(关联内容分组) :bigint           not null
#  recommend_id(推荐信息)         :bigint
#
# Indexes
#
#  index_contents_on_content_group_id  (content_group_id)
#
# Foreign Keys
#
#  fk_rails_...  (content_group_id => content_groups.id)
#
class Content < ApplicationRecord
  belongs_to :content_group
  belongs_to :compilation, optional: true
  belongs_to :book, optional: true
  belongs_to :author, optional: true
  belongs_to :recommend, optional: true

  scope :sorted, -> { order(sn: :asc, id: :desc) }

  enum :content_type, {
    compilation: 'compilation',           # 合辑
    book: 'book', # 单本
    author_display: 'author_display', # 作者显示
    recommend: 'recommend', # 推荐
    rank: 'rank', # 排行榜
  }, prefix: true

  CONTENT_TYPES = {
    compilation: '合辑',
    book: '单本',
    author_display: '作者显示',
    recommend: '推荐',
    rank: '排行榜'
  }.freeze

  def content_type_name
    return content_type if content_type.blank?
    CONTENT_TYPES[content_type.to_sym] || content_type
  end

  def display_img_url
    if content_group.group_type == "multi_images"
      img_url
    else
      if content_type == "compilation"
        compilation.banner_image_url
      elsif content_type == "book"
        book.cover_image_url
      elsif content_type == "author_display"
        author.head_img
      end
    end
  end

  def content_name
    if content_type == "compilation"
      compilation.name
    elsif content_type == "book"
      book.name
    elsif content_type == "author_display"
      author.name
    end
  end
end
