# frozen_string_literal: true

# 生产库 rm-bp18bg…/voicebook 与 haoqi_read 共用，这两张表由对方也在写入且不带 app_user_id；
# NOT NULL 会让对方的 insert 直接失败，所以线上放宽为可空（本应用仍有 belongs_to :app_user 强制必填）。
class RelaxAppUserIdNullOnSharedTables < ActiveRecord::Migration[8.0]
  def change
    change_column_null :orders, :app_user_id, true
    change_column_null :memberships, :app_user_id, true
  end
end
