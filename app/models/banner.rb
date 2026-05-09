# == Schema Information
#
# Table name: banners
#
#   id                   integer(8)         not null, primary key
#   title                string(255)        not null
#   image_url            string(255)        not null
#   link_url             string(255)        
#   link_type            integer(4)         not null, default(3)
#   position             integer(4)         not null, default(0)
#   sort_order           integer(4)         not null, default(0)
#   starts_at            datetime           
#   ends_at              datetime           
#   is_active            boolean            not null, default(1)
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_banners_on_is_active on is_active
#  Index: index_banners_on_sort_order on sort_order
#
#
# frozen_string_literal: true

# 轮播广告模型
# 管理首页轮播图和广告位
class Banner < ApplicationRecord
  # 链接类型枚举
  enum :link_type, { book: 0, collection: 1, url: 2, no_link: 3 }, default: :no_link

  # 验证规则
  validates :title, presence: true
  validates :image_url, presence: true
  validates :sort_order, presence: true

  # 作用域
  scope :active, -> { where(is_active: true).where("starts_at <= ? AND ends_at >= ?", Time.current, Time.current) }
  scope :ordered, -> { order(sort_order: :asc) }
  scope :by_position, ->(pos) { where(position: pos) }
end
