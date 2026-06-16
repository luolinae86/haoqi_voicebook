# frozen_string_literal: true

# == Schema Information
#
# Table name: content_groups
#
#  id                     :bigint           not null, primary key
#  group_type(小组类型)   :string(255)      not null
#  name(小组名称)         :string(255)      not null
#  sn(排序)               :integer          default(0)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  recommend_id(关联年级) :bigint           not null
#
# Indexes
#
#  index_content_groups_on_recommend_id  (recommend_id)
#
# Foreign Keys
#
#  fk_rails_...  (recommend_id => recommends.id)
#
class ContentGroup < ApplicationRecord
  belongs_to :recommend
  has_many :contents, dependent: :destroy

  enum :group_type, {
    multi_images: 'multi_images', # 多张图片
    one_row_three_columns: 'one_row_three_columns', # 一排3列
    one_row_display: 'one_row_display', # 一排展示
    two_rows_three_columns: 'two_rows_three_columns', # 双排3列展示
    one_row_two_columns: 'one_row_two_columns', # 一排双列
    single_column: 'single_column',         # 单列展示
    author_display: 'author_display',        # 作者展示
    sub_recommend: 'sub_recommend',          # 二级推荐
    single_row_vertical_column: 'single_row_vertical_column' # 单排竖列
  }, prefix: true

  GROUP_TYPE_NAMES = {
    multi_images: 'Banner',
    one_row_three_columns: '一排3列',
    one_row_display: '一排展示',
    two_rows_three_columns: '双排3列展示',
    one_row_two_columns: '一排双列',
    single_column: '单列展示',
    author_display: '作者展示',
    sub_recommend: '二级推荐',
    single_row_vertical_column: '单排竖列'
  }.freeze

  validates :name, presence: true, length: { maximum: 100 }
  validates :group_type, presence: true

  default_scope { order(sn: :asc, id: :desc) }
  scope :sorted, -> { order(sn: :asc, id: :desc) }

  def group_type_name
    return group_type if group_type.blank?
    GROUP_TYPE_NAMES[group_type.to_sym] || group_type
  end

end
