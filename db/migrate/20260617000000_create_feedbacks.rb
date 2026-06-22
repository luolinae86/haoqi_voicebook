# frozen_string_literal: true

class CreateFeedbacks < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:feedbacks)

    create_table :feedbacks do |t|
      t.integer :app_user_id, null: false, comment: "用户ID"
      t.integer :feedback_type, null: false, default: 0, comment: "反馈类型：0-功能问题 1-内容建议 2-其他"
      t.text :content, null: false, comment: "反馈内容"
      t.text :images, comment: "图片URL列表（JSON数组）"
      t.integer :status, null: false, default: 0, comment: "状态：0-待处理 1-处理中 2-已解决"
      t.timestamps
    end

    add_index :feedbacks, :app_user_id unless index_exists?(:feedbacks, :app_user_id)
    add_index :feedbacks, :status unless index_exists?(:feedbacks, :status)
  end
end
