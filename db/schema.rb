# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_04_30_200002) do
  create_table "api_auths", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "API认证表", force: :cascade do |t|
    t.string "name", null: false, comment: "客户端名称"
    t.string "access_key_id", null: false, comment: "客户端ID"
    t.string "access_key_secret", null: false, comment: "客户端密钥"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_key_id"], name: "index_api_auths_on_access_key_id", unique: true
  end

  create_table "app_users", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "用户表", force: :cascade do |t|
    t.string "phone", null: false, comment: "手机号"
    t.string "password_digest", comment: "加密密码"
    t.string "nickname", comment: "昵称"
    t.string "avatar", comment: "头像URL"
    t.integer "grade_id", comment: "年级ID"
    t.integer "role", default: 0, null: false, comment: "角色：0-孩子 1-家长 2-管理员"
    t.integer "reading_words", default: 0, null: false, comment: "阅读字数"
    t.integer "reading_minutes", default: 0, null: false, comment: "阅读时长(分钟)"
    t.integer "books_read", default: 0, null: false, comment: "读过的书(本)"
    t.boolean "is_vip", default: false, null: false, comment: "是否VIP"
    t.datetime "vip_expires_at", comment: "VIP过期时间"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 32
    t.index ["grade_id"], name: "index_app_users_on_grade_id"
    t.index ["is_vip"], name: "index_app_users_on_is_vip"
    t.index ["phone"], name: "index_app_users_on_phone", unique: true
    t.index ["uuid"], name: "index_app_users_on_uuid", unique: true
  end

  create_table "audio_albums", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "有声专辑表", force: :cascade do |t|
    t.integer "book_id", null: false, comment: "图书ID"
    t.string "narrator", comment: "主讲人/播音员"
    t.integer "total_episodes", default: 0, null: false, comment: "总集数"
    t.integer "total_duration", default: 0, null: false, comment: "总时长(秒)"
    t.text "description", comment: "专辑简介"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_audio_albums_on_book_id", unique: true
  end

  create_table "audio_episodes", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "有声节目表", force: :cascade do |t|
    t.integer "audio_album_id", null: false, comment: "专辑ID"
    t.string "title", null: false, comment: "节目标题"
    t.integer "sort_order", default: 0, null: false, comment: "排序"
    t.string "audio_url", comment: "音频URL"
    t.integer "duration", default: 0, null: false, comment: "时长(秒)"
    t.integer "play_count", default: 0, null: false, comment: "播放次数"
    t.boolean "is_free", default: false, null: false, comment: "是否免费"
    t.boolean "is_vip", default: false, null: false, comment: "是否VIP"
    t.datetime "published_at", comment: "发布时间"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audio_album_id", "sort_order"], name: "index_audio_episodes_on_audio_album_id_and_sort_order"
    t.index ["audio_album_id"], name: "index_audio_episodes_on_audio_album_id"
  end

  create_table "banners", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "轮播广告表", force: :cascade do |t|
    t.string "title", null: false, comment: "标题"
    t.string "image_url", null: false, comment: "图片URL"
    t.string "link_url", comment: "链接URL"
    t.integer "link_type", default: 3, null: false, comment: "链接类型：0-图书 1-合集 2-URL 3-无"
    t.integer "position", default: 0, null: false, comment: "位置"
    t.integer "sort_order", default: 0, null: false, comment: "排序"
    t.datetime "starts_at", comment: "开始时间"
    t.datetime "ends_at", comment: "结束时间"
    t.boolean "is_active", default: true, null: false, comment: "是否激活"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_banners_on_is_active"
    t.index ["sort_order"], name: "index_banners_on_sort_order"
  end

  create_table "blacklisted_books", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "黑名单图书表", force: :cascade do |t|
    t.integer "parental_control_id", null: false, comment: "家长管控ID"
    t.integer "book_id", null: false, comment: "图书ID"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_blacklisted_books_on_book_id"
    t.index ["parental_control_id", "book_id"], name: "index_blacklisted_books_on_parental_control_id_and_book_id", unique: true
    t.index ["parental_control_id"], name: "index_blacklisted_books_on_parental_control_id"
  end

  create_table "bookmarks", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "书签表", force: :cascade do |t|
    t.integer "app_user_id", null: false, comment: "用户ID"
    t.integer "book_id", null: false, comment: "图书ID"
    t.integer "chapter_id", comment: "章节ID"
    t.decimal "position", precision: 5, scale: 2, default: "0.0", comment: "位置(%)"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id"], name: "index_bookmarks_on_app_user_id"
    t.index ["book_id"], name: "index_bookmarks_on_book_id"
  end

  create_table "books", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "图书表", force: :cascade do |t|
    t.string "title", null: false, comment: "书名"
    t.string "author", comment: "作者"
    t.string "publisher", comment: "出版社"
    t.string "cover_image", comment: "封面图片URL"
    t.text "description", comment: "内容简介"
    t.integer "content_type", default: 0, null: false, comment: "类型：0-电子书 1-有声 2-视频 3-绘本"
    t.boolean "is_free", default: false, null: false, comment: "是否免费"
    t.boolean "is_vip", default: false, null: false, comment: "是否VIP"
    t.integer "category_id", comment: "分类ID"
    t.integer "grade_id", comment: "年级ID"
    t.integer "play_count", default: 0, null: false, comment: "播放/阅读次数"
    t.integer "word_count", default: 0, null: false, comment: "字数"
    t.decimal "rating", precision: 3, scale: 1, default: "0.0", comment: "评分"
    t.integer "status", default: 0, null: false, comment: "状态：0-草稿 1-已发布 2-已下架"
    t.string "isbn", comment: "ISBN"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "page_count", default: 0, null: false, comment: "电子书总页数"
    t.integer "import_status", default: 0, null: false, comment: "电子书导入状态"
    t.string "source_pdf_filename", comment: "源 PDF 文件名"
    t.string "source_pdf_path", comment: "源 PDF 存储路径"
    t.string "ebook_checksum", comment: "源 PDF 校验值"
    t.datetime "imported_at", comment: "导入完成时间"
    t.text "import_error_message", comment: "导入失败信息"
    t.string "epub_oss_key", comment: "EPUB 文件 OSS 路径"
    t.string "epub_oss_url", comment: "EPUB 文件公网 URL"
    t.integer "epub_export_status", default: 0, comment: "EPUB 导出状态：0-未导出 1-导出中 2-已完成 3-失败"
    t.text "epub_export_error", comment: "EPUB 导出失败原因"
    t.string "styles_oss_url", comment: "book.css 的 OSS URL"
    t.string "nav_oss_url", comment: "nav.xhtml 的 OSS URL"
    t.index ["category_id"], name: "index_books_on_category_id"
    t.index ["content_type"], name: "index_books_on_content_type"
    t.index ["created_at"], name: "index_books_on_created_at"
    t.index ["grade_id"], name: "index_books_on_grade_id"
    t.index ["import_status"], name: "index_books_on_import_status"
    t.index ["is_free"], name: "index_books_on_is_free"
    t.index ["is_vip"], name: "index_books_on_is_vip"
    t.index ["play_count"], name: "index_books_on_play_count"
    t.index ["rating"], name: "index_books_on_rating"
    t.index ["status"], name: "index_books_on_status"
  end

  create_table "bookshelves", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "书架表", force: :cascade do |t|
    t.integer "app_user_id", null: false, comment: "用户ID"
    t.integer "book_id", null: false, comment: "图书ID"
    t.decimal "reading_progress", precision: 5, scale: 2, default: "0.0", comment: "阅读进度(%)"
    t.integer "last_read_chapter_id", comment: "最后阅读章节ID"
    t.datetime "last_read_at", comment: "最后阅读时间"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id", "book_id"], name: "index_bookshelves_on_app_user_id_and_book_id", unique: true
    t.index ["app_user_id"], name: "index_bookshelves_on_app_user_id"
    t.index ["book_id"], name: "index_bookshelves_on_book_id"
  end

  create_table "categories", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "分类表", force: :cascade do |t|
    t.string "name", null: false, comment: "分类名称"
    t.integer "parent_id", comment: "父分类ID"
    t.integer "sort_order", default: 0, null: false, comment: "排序"
    t.string "icon", comment: "图标URL"
    t.string "description", comment: "描述"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["sort_order"], name: "index_categories_on_sort_order"
  end

  create_table "chapters", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "章节表", force: :cascade do |t|
    t.integer "book_id", null: false, comment: "图书ID"
    t.string "title", null: false, comment: "章节标题"
    t.integer "sort_order", default: 0, null: false, comment: "排序"
    t.text "content", comment: "章节内容"
    t.boolean "is_free", default: false, null: false, comment: "是否免费"
    t.boolean "is_vip", default: false, null: false, comment: "是否VIP"
    t.integer "word_count", default: 0, null: false, comment: "字数"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "sort_order"], name: "index_chapters_on_book_id_and_sort_order"
    t.index ["book_id"], name: "index_chapters_on_book_id"
  end

  create_table "collection_items", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "合集项表", force: :cascade do |t|
    t.integer "collection_id", null: false, comment: "合集ID"
    t.integer "book_id", null: false, comment: "图书ID"
    t.integer "sort_order", default: 0, null: false, comment: "排序"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_collection_items_on_book_id"
    t.index ["collection_id", "book_id"], name: "index_collection_items_on_collection_id_and_book_id", unique: true
    t.index ["collection_id"], name: "index_collection_items_on_collection_id"
  end

  create_table "collections", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "专题合集表", force: :cascade do |t|
    t.string "title", null: false, comment: "合集标题"
    t.text "description", comment: "合集描述"
    t.string "cover_image", comment: "封面图片URL"
    t.integer "sort_order", default: 0, null: false, comment: "排序"
    t.integer "collection_type", default: 0, null: false, comment: "类型：0-专题 1-分级 2-热门 3-新上架"
    t.integer "target_grade_id", comment: "目标年级ID"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_type"], name: "index_collections_on_collection_type"
    t.index ["sort_order"], name: "index_collections_on_sort_order"
    t.index ["target_grade_id"], name: "index_collections_on_target_grade_id"
  end

  create_table "ebook_pages", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "电子书页面表", force: :cascade do |t|
    t.bigint "book_id", null: false, comment: "图书ID"
    t.integer "page_number", null: false, comment: "页码"
    t.decimal "page_width", precision: 8, scale: 2, null: false, comment: "页面宽度(pt)"
    t.decimal "page_height", precision: 8, scale: 2, null: false, comment: "页面高度(pt)"
    t.text "plain_text", comment: "页面纯文本"
    t.json "rich_content", null: false, comment: "页面富文本块"
    t.integer "word_count", default: 0, null: false, comment: "字数"
    t.integer "block_count", default: 0, null: false, comment: "块数量"
    t.integer "image_count", default: 0, null: false, comment: "图片数量"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "xhtml_content", comment: "页面 XHTML 内容"
    t.index ["book_id", "page_number"], name: "index_ebook_pages_on_book_id_and_page_number", unique: true
    t.index ["book_id"], name: "index_ebook_pages_on_book_id"
  end

  create_table "grades", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "年级表", force: :cascade do |t|
    t.string "name", null: false, comment: "年级名称"
    t.integer "level", null: false, comment: "年级等级"
    t.integer "sort_order", default: 0, null: false, comment: "排序"
    t.string "description", comment: "描述"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["level"], name: "index_grades_on_level", unique: true
    t.index ["sort_order"], name: "index_grades_on_sort_order"
  end

  create_table "hot_searches", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "热门搜索表", force: :cascade do |t|
    t.string "keyword", null: false, comment: "关键词"
    t.integer "search_count", default: 0, null: false, comment: "搜索次数"
    t.integer "sort_order", default: 0, null: false, comment: "排序"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["keyword"], name: "index_hot_searches_on_keyword", unique: true
    t.index ["sort_order"], name: "index_hot_searches_on_sort_order"
  end

  create_table "memberships", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "会员表", force: :cascade do |t|
    t.integer "app_user_id", null: false, comment: "用户ID"
    t.integer "plan_type", default: 0, null: false, comment: "套餐：0-月度 1-季度 2-年度"
    t.decimal "price", precision: 10, scale: 2, null: false, comment: "实付价格"
    t.decimal "original_price", precision: 10, scale: 2, comment: "原价"
    t.date "start_date", null: false, comment: "开始日期"
    t.date "end_date", null: false, comment: "结束日期"
    t.integer "status", default: 0, null: false, comment: "状态：0-待支付 1-有效 2-已过期 3-已取消"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id"], name: "index_memberships_on_app_user_id"
    t.index ["end_date"], name: "index_memberships_on_end_date"
    t.index ["status"], name: "index_memberships_on_status"
  end

  create_table "orders", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "订单表", force: :cascade do |t|
    t.integer "app_user_id", null: false, comment: "用户ID"
    t.string "order_no", null: false, comment: "订单号"
    t.decimal "amount", precision: 10, scale: 2, null: false, comment: "金额"
    t.integer "payment_method", default: 0, null: false, comment: "支付方式：0-支付宝 1-微信"
    t.integer "status", default: 0, null: false, comment: "状态：0-待支付 1-已支付 2-失败 3-已退款"
    t.datetime "paid_at", comment: "支付时间"
    t.integer "membership_id", comment: "会员ID"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id"], name: "index_orders_on_app_user_id"
    t.index ["membership_id"], name: "index_orders_on_membership_id"
    t.index ["order_no"], name: "index_orders_on_order_no", unique: true
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "parental_controls", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "家长管控表", force: :cascade do |t|
    t.integer "app_user_id", null: false, comment: "用户ID"
    t.string "password_digest", null: false, comment: "家长密码"
    t.string "phone", comment: "家长手机号"
    t.integer "time_limit_minutes", comment: "时间限制(分钟)"
    t.boolean "is_active", default: true, null: false, comment: "是否启用"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id"], name: "index_parental_controls_on_app_user_id", unique: true
  end

  create_table "ranking_items", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "排行项表", force: :cascade do |t|
    t.integer "ranking_id", null: false, comment: "排行榜ID"
    t.integer "book_id", null: false, comment: "图书ID"
    t.integer "rank", null: false, comment: "排名"
    t.decimal "score", precision: 5, scale: 2, default: "0.0", comment: "得分"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_ranking_items_on_book_id"
    t.index ["ranking_id", "book_id"], name: "index_ranking_items_on_ranking_id_and_book_id", unique: true
    t.index ["ranking_id", "rank"], name: "index_ranking_items_on_ranking_id_and_rank"
    t.index ["ranking_id"], name: "index_ranking_items_on_ranking_id"
  end

  create_table "rankings", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "排行榜表", force: :cascade do |t|
    t.string "name", null: false, comment: "榜单名称"
    t.integer "ranking_type", default: 0, null: false, comment: "类型：0-热度 1-高分 2-上新 3-大奖 4-名著"
    t.string "description", comment: "描述"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ranking_type"], name: "index_rankings_on_ranking_type"
  end

  create_table "reading_levels", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "分级阅读表", force: :cascade do |t|
    t.string "name", null: false, comment: "级别名称"
    t.integer "level", null: false, comment: "级别"
    t.text "description", comment: "描述"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["level"], name: "index_reading_levels_on_level", unique: true
  end

  create_table "reading_records", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "阅读记录表", force: :cascade do |t|
    t.integer "app_user_id", null: false, comment: "用户ID"
    t.integer "book_id", null: false, comment: "图书ID"
    t.integer "chapter_id", comment: "章节ID"
    t.integer "words_read", default: 0, null: false, comment: "阅读字数"
    t.integer "duration_minutes", default: 0, null: false, comment: "阅读时长(分钟)"
    t.datetime "read_at", comment: "阅读时间"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id"], name: "index_reading_records_on_app_user_id"
    t.index ["book_id"], name: "index_reading_records_on_book_id"
    t.index ["read_at"], name: "index_reading_records_on_read_at"
  end

  create_table "recommendation_items", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "推荐项表", force: :cascade do |t|
    t.integer "recommendation_id", null: false, comment: "推荐ID"
    t.integer "book_id", null: false, comment: "图书ID"
    t.integer "sort_order", default: 0, null: false, comment: "排序"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_recommendation_items_on_book_id"
    t.index ["recommendation_id", "book_id"], name: "index_recommendation_items_on_recommendation_id_and_book_id", unique: true
    t.index ["recommendation_id"], name: "index_recommendation_items_on_recommendation_id"
  end

  create_table "recommendations", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "推荐表", force: :cascade do |t|
    t.string "title", null: false, comment: "推荐标题"
    t.text "description", comment: "推荐描述"
    t.integer "recommendation_type", default: 0, null: false, comment: "类型：0-精选 1-分级 2-热门 3-新书 4-专题"
    t.integer "target_grade_id", comment: "目标年级ID"
    t.integer "sort_order", default: 0, null: false, comment: "排序"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recommendation_type"], name: "index_recommendations_on_recommendation_type"
    t.index ["sort_order"], name: "index_recommendations_on_sort_order"
    t.index ["target_grade_id"], name: "index_recommendations_on_target_grade_id"
  end

  create_table "sms_verifications", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "短信验证码表", force: :cascade do |t|
    t.string "phone", null: false, comment: "手机号"
    t.string "code", null: false, comment: "验证码"
    t.boolean "verified", default: false, null: false, comment: "是否已验证"
    t.datetime "expires_at", null: false, comment: "过期时间"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_sms_verifications_on_expires_at"
    t.index ["phone", "code"], name: "index_sms_verifications_on_phone_and_code"
  end

  add_foreign_key "ebook_pages", "books"
end
