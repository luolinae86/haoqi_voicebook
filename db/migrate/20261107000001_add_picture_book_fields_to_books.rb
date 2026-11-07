# frozen_string_literal: true

class AddPictureBookFieldsToBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :books, :source_book_no, :string, comment: "外部资源编号（供应资源包名，如 61355）"
    add_column :books, :narration_oss_key, :string, comment: "旁白音频 OSS 路径"
    add_column :books, :narration_oss_url, :string, comment: "旁白音频公网 URL"
    add_column :books, :total_duration_ms, :integer, comment: "旁白总时长（毫秒）"
    add_column :books, :asr_raw, :json, comment: "实时 ASR 原始句子与词时间（重试不再重复调用）"
    add_column :books, :book_json_oss_key, :string, comment: "book.json OSS 路径"
    add_column :books, :book_json_oss_url, :string, comment: "book.json 公网 URL"
    add_column :books, :dict_json_oss_key, :string, comment: "dict.json OSS 路径"
    add_column :books, :dict_json_oss_url, :string, comment: "dict.json 公网 URL"

    add_index :books, :source_book_no
  end
end
