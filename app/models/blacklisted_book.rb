# == Schema Information
#
# Table name: blacklisted_books
#
#   id                   integer(8)         not null, primary key
#   parental_control_id  integer(4)         not null
#   book_id              integer(4)         not null
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_blacklisted_books_on_parental_control_id_and_book_id on parental_control_id, book_id (unique)
#  Index: index_blacklisted_books_on_parental_control_id on parental_control_id
#  Index: index_blacklisted_books_on_book_id on book_id
#
#
# frozen_string_literal: true

# 黑名单图书模型
# 管理家长设置的内容黑名单，被加入黑名单的书籍孩子不可见
class BlacklistedBook < ApplicationRecord
  # 关联关系
  belongs_to :parental_control # 所属家长管控
  belongs_to :book # 被屏蔽的图书

  # 验证规则
  validates :parental_control_id, uniqueness: { scope: :book_id, message: "该图书已在黑名单中" }
end
