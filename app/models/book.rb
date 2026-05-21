# frozen_string_literal: true

# == Schema Information
#
# Table name: books
#
#  id                                                                   :bigint           not null, primary key
#  compilations                                                         :bigint
#  content_description(书籍简介)                                          :text
#  content_type(类型：0-电子书 1-有声 2-视频 3-绘本)                    :integer          default("ebook"), not null
#  content_file_url(电子书内容文件URL)                                  :string(255)
#  content_file_type(内容文件类型 (epub/pdf))                           :string(255)
#  content_file_name(内容文件名)                                        :string(255)
#  cover_image_url(绘本封面URL)                                         :string(255)
#  ebook_checksum(源 PDF 校验值)                                        :string(255)
#  epub_export_error(EPUB 导出失败原因)                                 :text(65535)
#  epub_export_status(EPUB 导出状态：0-未导出 1-导出中 2-已完成 3-失败) :integer          default("not_exported")
#  epub_oss_key(EPUB 文件 OSS 路径)                                     :string(255)
#  epub_oss_url(EPUB 文件公网 URL)                                      :string(255)
#  import_error_message(导入失败信息)                                   :text(65535)
#  import_status(电子书导入状态)                                        :integer          default("not_imported"), not null
#  imported_at(导入完成时间)                                            :datetime
#  is_free(是否免费)                                                    :boolean          default(FALSE), not null
#  is_vip(是否VIP)                                                      :boolean          default(FALSE), not null
#  isbn(ISBN)                                                           :string(255)
#  name(绘本名称)                                                       :string(255)      not null
#  nav_oss_url(nav.xhtml 的 OSS URL)                                    :string(255)
#  page_count(电子书总页数)                                             :integer          default(0), not null
#  play_count(播放/阅读次数)                                            :integer          default(0), not null
#  rating(评分)                                                         :decimal(3, 1)    default(0.0)
#  source_pdf_filename(源 PDF 文件名)                                   :string(255)
#  source_pdf_path(源 PDF 存储路径)                                     :string(255)
#  status(状态：0-草稿 1-已发布 2-已下架)                               :integer          default("draft"), not null
#  styles_oss_url(book.css 的 OSS URL)                                  :string(255)
#  themes(主题)                                                         :json
#  word_count(字数)                                                     :integer          default(0), not null
#  created_at                                                           :datetime         not null
#  updated_at                                                           :datetime         not null
#  author_id                                                            :bigint
#  book_level_id                                                        :bigint
#  category_id(绘本类型)                                                :bigint
#  grade_id(年级ID)                                                     :bigint
#  supplier_id(归属供应商)                                              :bigint
#
# Indexes
#
#  index_books_on_category_id    (category_id)
#  index_books_on_import_status  (import_status)
#  index_books_on_name           (name)
#  index_books_on_status         (status)
#  index_books_on_supplier_id    (supplier_id)
#
# Foreign Keys
#
#  fk_rails_...  (supplier_id => suppliers.id)
#
class Book < ApplicationRecord
  belongs_to :supplier, optional: true
  belongs_to :category, optional: true
  belongs_to :author, optional: true
  has_and_belongs_to_many :grades, join_table: :book_grades
  has_and_belongs_to_many :compilations, join_table: :compilation_books
  has_and_belongs_to_many :category_subs, join_table: :category_sub_books
  has_many :contents

  # voicebook-specific associations
  has_many :bookshelves, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :blacklisted_books, dependent: :destroy
  has_many :ebook_pages, dependent: :destroy
  has_many :book_chapters, dependent: :destroy
  has_many :chapters, dependent: :destroy
  has_one :book_stats, dependent: :destroy
  has_many :reading_sessions, dependent: :destroy
  has_many :reading_progresses, dependent: :destroy

  # 验证
  validates :name, presence: true, length: { maximum: 100 }

  # voicebook scopes
  enum :status, { draft: 0, published: 1, offline: 2 }
  enum :content_type, { ebook: 0, audio: 1, video: 2, picture_book: 3 }
  enum :import_status, { not_imported: 0, processing: 1, ready: 2, failed: 3 }, default: :not_imported
  enum :epub_export_status, { not_exported: 0, exporting: 1, completed: 2, export_failed: 3 }, default: :not_exported, prefix: true

  scope :published_books, -> { where(status: :published) }
  scope :by_type, ->(type) { where(content_type: type) }
  scope :by_category, ->(id) { where(category_id: id) }
  scope :by_grade, ->(id) { where(grade_id: id) }
  scope :free_books, -> { where(is_free: true) }
  scope :popular, -> { order(play_count: :desc) }
  scope :highest_rated, -> { order(rating: :desc) }
  scope :recently_added, -> { order(created_at: :desc) }

  # OSS URL 签名辅助方法（统一使用，处理中文路径）
  def self.sign_oss_url(url)
    return nil if url.blank?
    return url unless url.include?("aliyuncs.com")

    # 提取 object_key（使用 URL 中的实际 bucket 名称）
    begin
      uri = URI.parse(url)
      host_parts = uri.host.to_s.split(".", 2)
      return url if host_parts.size < 2
      object_key = uri.path.sub(/\A\//, "")
    rescue URI::InvalidURIError
      # 非 ASCII URL（含中文），用正则提取
      if url =~ %r{\Ahttps?://([^/]+)(/.*)?\z}
        host_parts = $1.split(".", 2)
        return url if host_parts.size < 2
        object_key = ($2 || "/").sub(/\A\//, "")
      else
        return url
      end
    end

    bucket_name = host_parts.first
    endpoint = host_parts.last
    object_key = CGI.unescape(object_key)

    expires_at = Time.now.to_i + 3600
    canonicalized_resource = "/#{bucket_name}/#{object_key}"
    string_to_sign = "GET\n\n\n#{expires_at}\n#{canonicalized_resource}"

    signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest("sha1", OSS_ACCESS_KEY_SECRET, string_to_sign)
    )

    query = "Expires=#{expires_at}&OSSAccessKeyId=#{OSS_ACCESS_KEY_ID}&Signature=#{CGI.escape(signature)}"
    "https://#{bucket_name}.#{endpoint}/#{CGI.escape(object_key)}?#{query}"
  rescue StandardError
    url
  end

  def themes_array
    themes || []
  end

  private

  def self.ransackable_attributes(auth_object = nil)
    ["author", "id", "name", "supplier_id", "themes", "status", "content_type", "is_free", "is_vip", "category_id", "grade_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["category", "compilations", "grades", "supplier", "author", "ebook_pages", "book_chapters", "book_stats"]
  end
end
