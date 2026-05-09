# frozen_string_literal: true

class ContentGroup < ApplicationRecord
  belongs_to :recommend
  has_many :contents, dependent: :destroy

  enum :group_type, {
    multi_images: 'multi_images',           # 多张图片
    one_row_three_columns: 'one_row_three_columns', # 一排3列
    one_row_display: 'one_row_display',     # 一排展示
    two_rows_three_columns: 'two_rows_three_columns', # 双排3列展示
    one_row_two_columns: 'one_row_two_columns', # 一排双列
    single_column: 'single_column',         # 单列展示
    author_display: 'author_display'        # 作者展示
  }, prefix: true

  GROUP_TYPE_NAMES = {
    multi_images: 'Banner',
    one_row_three_columns: '一排3列',
    one_row_display: '一排展示',
    two_rows_three_columns: '双排3列展示',
    one_row_two_columns: '一排双列',
    single_column: '单列展示',
    author_display: '作者展示'
  }.freeze

  validates :name, presence: true, length: { maximum: 100 }
  validates :group_type, presence: true

  default_scope { order(sn: :asc, id: :desc) }
  scope :sorted, -> { order(sn: :asc, id: :desc) }

  def group_type_name
    GROUP_TYPE_NAMES[group_type.to_sym] || group_type
  end

end
