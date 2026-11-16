# frozen_string_literal: true

# 对应共用库中 haoqi_read 写入的 book_contents 表（绘本图片页 + 时间戳）。
# voicebook 只读，由 haoqi_read 的 admin 后台维护。
class BookContent < ApplicationRecord
  belongs_to :book
end
