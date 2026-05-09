class Content < ApplicationRecord
  belongs_to :content_group
  belongs_to :compilation, optional: true
  belongs_to :book, optional: true
  belongs_to :author, optional: true

  scope :sorted, -> { order(sn: :asc, id: :desc) }

  enum :content_type, {
    compilation: 'compilation',           # 合辑
    book: 'book', # 单本
    author_display: 'author_display', # 作者显示
  }, prefix: true

  CONTENT_TYPES = {
    compilation: '合辑',
    book: '单本',
    author_display: '作者显示'
  }.freeze

  def content_type_name
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
