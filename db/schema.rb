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

ActiveRecord::Schema[8.0].define(version: 2026_05_28_100000) do
  create_table "api_auths", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "API认证表", force: :cascade do |t|
    t.string "name", null: false, comment: "客户端名称"
    t.string "access_key_id", null: false, comment: "客户端ID"
    t.string "access_key_secret", null: false, comment: "客户端密钥"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_key_id"], name: "index_api_auths_on_access_key_id", unique: true
  end

  create_table "app_users", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "用户表", force: :cascade do |t|
    t.string "phone", comment: "手机号"
    t.string "password_digest", comment: "加密密码"
    t.string "nickname", comment: "昵称"
    t.bigint "grade_id", comment: "年级ID"
    t.integer "role", default: 0, null: false, comment: "角色：0-孩子 1-家长 2-管理员"
    t.integer "reading_words", default: 0, null: false, comment: "阅读字数"
    t.integer "reading_minutes", default: 0, null: false, comment: "阅读时长(分钟)"
    t.integer "books_read", default: 0, null: false, comment: "读过的书(本)"
    t.boolean "is_vip", default: false, null: false, comment: "是否VIP"
    t.datetime "vip_expires_at", comment: "VIP过期时间"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "device_id", limit: 64
    t.string "wechat_openid", comment: "微信openid"
    t.string "qq_openid", comment: "QQ openid"
    t.string "uuid", null: false
    t.bigint "head_img_id", comment: "用户头像ID"
    t.index ["device_id"], name: "index_app_users_on_device_id", unique: true
    t.index ["grade_id"], name: "index_app_users_on_grade_id"
    t.index ["is_vip"], name: "index_app_users_on_is_vip"
    t.index ["phone"], name: "index_app_users_on_phone", unique: true
    t.index ["qq_openid"], name: "index_app_users_on_qq_openid", unique: true
    t.index ["uuid"], name: "index_app_users_on_uuid", unique: true
    t.index ["wechat_openid"], name: "index_app_users_on_wechat_openid", unique: true
  end

  create_table "authors", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", null: false, comment: "作者名"
    t.string "head_img", null: false, comment: "头像"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "blacklisted_books", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "parental_control_id", null: false, comment: "家长管控ID"
    t.integer "book_id", null: false, comment: "图书ID"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_blacklisted_books_on_book_id"
    t.index ["parental_control_id", "book_id"], name: "index_blacklisted_books_on_parental_control_id_and_book_id", unique: true
    t.index ["parental_control_id"], name: "index_blacklisted_books_on_parental_control_id"
  end

  create_table "book_grades", id: false, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.bigint "grade_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "grade_id"], name: "index_book_grades_on_book_id_and_grade_id", unique: true
    t.index ["book_id"], name: "index_book_grades_on_book_id"
    t.index ["grade_id"], name: "index_book_grades_on_grade_id"
  end

  create_table "book_levels", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", limit: 50, null: false, comment: "等级名称"
    t.integer "sn", default: 0, null: false, comment: "序号"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "book_stats", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "图书统计表", force: :cascade do |t|
    t.bigint "book_id", null: false, comment: "图书ID"
    t.integer "total_readers", default: 0, null: false, comment: "总阅读人数(去重)"
    t.integer "total_reads", default: 0, null: false, comment: "总阅读次数"
    t.integer "total_duration_seconds", default: 0, null: false, comment: "总阅读时长(秒)"
    t.integer "total_words_read", default: 0, null: false, comment: "总阅读字数"
    t.integer "completed_count", default: 0, null: false, comment: "完读人数"
    t.float "completion_rate", default: 0.0, null: false, comment: "完读率"
    t.integer "weekly_readers", default: 0, null: false, comment: "近7天阅读人数"
    t.integer "weekly_reads", default: 0, null: false, comment: "近7天阅读次数"
    t.integer "monthly_readers", default: 0, null: false, comment: "近30天阅读人数"
    t.integer "monthly_reads", default: 0, null: false, comment: "近30天阅读次数"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_book_stats_on_book_id", unique: true
    t.index ["monthly_readers"], name: "index_book_stats_on_monthly_readers"
    t.index ["weekly_readers"], name: "index_book_stats_on_weekly_readers"
  end

  create_table "bookmarks", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "app_user_id", null: false, comment: "用户ID"
    t.integer "book_id", null: false, comment: "图书ID"
    t.integer "chapter_id", comment: "章节ID"
    t.decimal "position", precision: 5, scale: 2, default: "0.0", comment: "位置(%)"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id"], name: "index_bookmarks_on_app_user_id"
    t.index ["book_id"], name: "index_bookmarks_on_book_id"
  end

  create_table "books", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", null: false, comment: "绘本名称"
    t.string "cover_image_url", comment: "绘本封面URL"
    t.bigint "category_id", comment: "绘本类型"
    t.json "themes", comment: "主题"
    t.bigint "supplier_id", comment: "归属供应商"
    t.bigint "book_level_id"
    t.bigint "author_id"
    t.bigint "compilations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "content_type", default: 0, null: false, comment: "类型：0-电子书 1-有声 2-视频 3-绘本"
    t.boolean "is_free", default: false, null: false, comment: "是否免费"
    t.boolean "is_vip", default: false, null: false, comment: "是否VIP"
    t.bigint "grade_id", comment: "年级ID"
    t.integer "play_count", default: 0, null: false, comment: "播放/阅读次数"
    t.integer "word_count", default: 0, null: false, comment: "字数"
    t.decimal "rating", precision: 3, scale: 1, default: "0.0", comment: "评分"
    t.integer "status", default: 0, null: false, comment: "状态：0-草稿 1-已发布 2-已下架"
    t.string "isbn", comment: "ISBN"
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
    t.string "content_file_url", comment: "电子书内容文件URL"
    t.string "content_file_type", comment: "内容文件类型 (epub/pdf)"
    t.string "content_file_name", comment: "内容文件名"
    t.text "content_description"
    t.index ["category_id"], name: "index_books_on_category_id"
    t.index ["import_status"], name: "index_books_on_import_status"
    t.index ["name"], name: "index_books_on_name"
    t.index ["status"], name: "index_books_on_status"
    t.index ["supplier_id"], name: "index_books_on_supplier_id"
  end

  create_table "bookshelves", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "书架表", force: :cascade do |t|
    t.integer "app_user_id", null: false, comment: "用户ID"
    t.bigint "book_id", null: false, comment: "图书ID"
    t.decimal "reading_progress", precision: 5, scale: 2, default: "0.0", comment: "阅读进度(%)"
    t.bigint "last_read_chapter_id", comment: "最后阅读章节ID"
    t.datetime "last_read_at", comment: "最后阅读时间"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id", "book_id"], name: "index_bookshelves_on_app_user_id_and_book_id", unique: true
    t.index ["app_user_id"], name: "index_bookshelves_on_app_user_id"
    t.index ["book_id"], name: "index_bookshelves_on_book_id"
  end

  create_table "catalogues", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "book_id", null: false, comment: "图书ID"
    t.integer "chapter_number", null: false, comment: "章节序号"
    t.string "chapter_name", null: false, comment: "章节名称"
    t.integer "start_page_number", null: false, comment: "起始页码"
    t.boolean "is_free", default: false, null: false, comment: "是否免费"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "word_count", default: 0, null: false, comment: "章节字数"
    t.index ["book_id"], name: "index_catalogues_on_book_id"
  end

  create_table "categories", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.integer "level", default: 1, null: false
    t.integer "sn", default: 0
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["level"], name: "index_categories_on_level"
  end

  create_table "category_sub_books", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "category_sub_id", null: false
    t.bigint "book_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "category_sub_id"], name: "index_category_sub_books_on_book_id_and_category_sub_id", unique: true
    t.index ["book_id"], name: "index_category_sub_books_on_book_id"
    t.index ["category_sub_id"], name: "index_category_sub_books_on_category_sub_id"
  end

  create_table "category_subs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "category_id", null: false, comment: "关联分类"
    t.string "name", null: false, comment: "子类名称"
    t.string "icon", comment: "图标URL"
    t.integer "sn", default: 0, comment: "排序"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_category_subs_on_category_id"
  end

  create_table "chapters", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "章节表（有声/视频章节）", force: :cascade do |t|
    t.bigint "book_id", null: false, comment: "所属图书"
    t.string "name", null: false, comment: "章节名称"
    t.string "cover_image_url", comment: "章节封面图片URL"
    t.string "content_file_url", comment: "章节内容文件URL（音频/视频）"
    t.string "content_file_name", comment: "章节内容文件名"
    t.string "content_file_type", comment: "内容文件类型 (mp3/mp4/wav等)"
    t.boolean "is_free", default: false, comment: "是否免费"
    t.boolean "is_published", default: false, comment: "是否已发布"
    t.integer "sn", default: 0, comment: "排序"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "duration", comment: "音频/视频时长（秒）"
    t.date "publish_date", comment: "发布日期"
    t.index ["book_id"], name: "index_chapters_on_book_id"
  end

  create_table "compilation_books", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "compilation_id", null: false
    t.bigint "book_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_compilation_books_on_book_id"
    t.index ["compilation_id", "book_id"], name: "index_compilation_books_on_compilation_id_and_book_id", unique: true
    t.index ["compilation_id"], name: "index_compilation_books_on_compilation_id"
  end

  create_table "compilation_categories", id: false, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "compilation_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_compilation_categories_on_category_id"
    t.index ["compilation_id", "category_id"], name: "index_compilation_categories_on_compilation_id_and_category_id", unique: true
    t.index ["compilation_id"], name: "index_compilation_categories_on_compilation_id"
  end

  create_table "compilation_grades", id: false, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "compilation_id", null: false
    t.bigint "grade_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["compilation_id", "grade_id"], name: "index_compilation_grades_on_compilation_id_and_grade_id", unique: true
    t.index ["compilation_id"], name: "index_compilation_grades_on_compilation_id"
    t.index ["grade_id"], name: "index_compilation_grades_on_grade_id"
  end

  create_table "compilations", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", null: false, comment: "合辑名称"
    t.string "banner_image_url", comment: "合辑banner图片URL (1500x932, <=500KB)"
    t.string "banner_image_name", comment: "合辑banner图片文件名"
    t.string "landscape_cover_url", comment: "横图封面URL (1125x540, <=500KB)"
    t.string "landscape_cover_name", comment: "横图封面文件名"
    t.string "editor_recommendation", limit: 15, comment: "编辑推荐语（15字以内）"
    t.string "publisher", comment: "出版社"
    t.integer "total_count", default: 0, comment: "合辑总集数"
    t.string "author", comment: "作者"
    t.string "tags", comment: "内容标签"
    t.string "intro_image_url", comment: "图片简介URL"
    t.string "intro_image_name", comment: "图片简介文件名"
    t.text "content_description", comment: "合辑简介（富文本/Markdown）"
    t.text "description", comment: "内容简介"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "portrait_cover_url"
    t.string "portrait_cover_name"
    t.string "square_cover_url"
    t.string "square_cover_name"
    t.index ["name"], name: "index_compilations_on_name", unique: true
  end

  create_table "content_groups", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "recommend_id", null: false, comment: "关联年级"
    t.string "name", null: false, comment: "小组名称"
    t.string "group_type", null: false, comment: "小组类型"
    t.integer "sn", default: 0, comment: "排序"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recommend_id"], name: "index_content_groups_on_recommend_id"
  end

  create_table "contents", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "content_group_id", null: false, comment: "关联内容分组"
    t.string "content_type", null: false, comment: "类型"
    t.string "img_url", comment: "图片链接"
    t.bigint "compilation_id", comment: "合辑信息"
    t.bigint "book_id", comment: "单本信息"
    t.bigint "recommend_id", comment: "推荐信息"
    t.bigint "author_id", comment: "作者信息"
    t.integer "sn", default: 0, comment: "排序"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_group_id"], name: "index_contents_on_content_group_id"
  end

  create_table "devices", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "app_user_id"
    t.string "device_id", limit: 64, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id"], name: "index_devices_on_app_user_id"
    t.index ["device_id"], name: "index_devices_on_device_id", unique: true
  end

  create_table "ebook_pages", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "电子书页面表", force: :cascade do |t|
    t.bigint "book_id", null: false, comment: "图书ID"
    t.integer "page_number", null: false, comment: "页码"
    t.integer "word_count", default: 0, null: false, comment: "字数"
    t.text "xhtml_content", comment: "页面 XHTML 内容"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image_url", comment: "页面图片URL（PDF导入）"
    t.index ["book_id", "page_number"], name: "index_ebook_pages_on_book_id_and_page_number", unique: true
    t.index ["book_id"], name: "index_ebook_pages_on_book_id"
  end

  create_table "grades", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "group_name", limit: 8
    t.string "name", limit: 16
    t.string "description", limit: 32
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "head_imgs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "img_url", comment: "头像URL"
    t.boolean "is_vip", default: false, comment: "是否VIP用户可用"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "hot_searches", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "热门搜索表", force: :cascade do |t|
    t.string "keyword", null: false, comment: "关键词"
    t.integer "search_count", default: 0, null: false, comment: "搜索次数"
    t.integer "sort_order", default: 0, null: false, comment: "排序"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_active", default: true, null: false, comment: "是否启用"
    t.index ["is_active", "sort_order"], name: "index_hot_searches_on_is_active_and_sort_order"
    t.index ["keyword"], name: "index_hot_searches_on_keyword", unique: true
  end

  create_table "leaderboard_items", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "排行榜项表", force: :cascade do |t|
    t.bigint "leaderboard_id", null: false, comment: "排行榜ID"
    t.bigint "book_id", null: false, comment: "图书ID"
    t.integer "rank", null: false, comment: "排名"
    t.decimal "score", precision: 10, scale: 2, default: "0.0", comment: "得分"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["leaderboard_id", "book_id"], name: "index_leaderboard_items_on_leaderboard_id_and_book_id", unique: true
    t.index ["leaderboard_id", "rank"], name: "index_leaderboard_items_on_leaderboard_id_and_rank"
    t.index ["leaderboard_id"], name: "index_leaderboard_items_on_leaderboard_id"
  end

  create_table "leaderboards", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "排行榜表", force: :cascade do |t|
    t.string "name", null: false, comment: "榜单名称"
    t.string "slug", null: false, comment: "唯一标识"
    t.integer "ranking_type", default: 0, null: false, comment: "0-自动 1-手动"
    t.string "auto_rule", comment: "自动规则"
    t.string "category_filter", comment: "按分类过滤"
    t.integer "limit_count", default: 50, comment: "最多展示数量"
    t.boolean "is_active", default: true, null: false, comment: "是否启用"
    t.integer "sort_order", default: 0, null: false, comment: "展示排序"
    t.datetime "last_calculated_at", comment: "自动榜单最后计算时间"
    t.text "description", comment: "榜单描述"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ranking_type", "is_active"], name: "index_leaderboards_on_ranking_type_and_is_active"
    t.index ["slug"], name: "index_leaderboards_on_slug", unique: true
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

  create_table "packages", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.float "price"
    t.float "origin_price"
    t.integer "effective_days"
    t.integer "sn", default: 0
    t.boolean "is_delete", default: false
    t.boolean "is_discount", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_delete"], name: "index_packages_on_is_delete"
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

  create_table "reading_progress", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "阅读进度表", force: :cascade do |t|
    t.bigint "app_user_id", null: false, comment: "用户ID"
    t.bigint "book_id", null: false, comment: "图书ID"
    t.integer "last_page_number", default: 1, null: false, comment: "最新阅读到的页码"
    t.integer "total_words_read", default: 0, null: false, comment: "本书累计阅读字数"
    t.integer "total_duration_seconds", default: 0, null: false, comment: "本书累计阅读时长(秒)"
    t.integer "session_count", default: 0, null: false, comment: "阅读次数"
    t.boolean "completed", default: false, null: false, comment: "是否已读完"
    t.datetime "completed_at", comment: "完读时间"
    t.datetime "last_read_at", null: false, comment: "最近阅读时间"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id", "book_id"], name: "index_reading_progress_on_app_user_id_and_book_id", unique: true
    t.index ["book_id"], name: "index_reading_progress_on_book_id"
  end

  create_table "reading_sessions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "阅读记录表", force: :cascade do |t|
    t.bigint "app_user_id", null: false, comment: "用户ID"
    t.bigint "book_id", null: false, comment: "图书ID"
    t.integer "page_number", default: 1, null: false, comment: "阅读到的页码"
    t.integer "word_count", default: 0, null: false, comment: "本次阅读字数"
    t.integer "duration_seconds", default: 0, null: false, comment: "本次阅读时长(秒)"
    t.datetime "started_at", null: false, comment: "开始阅读时间"
    t.datetime "ended_at", comment: "结束阅读时间"
    t.string "read_date", null: false, comment: "阅读日期 YYYY-MM-DD"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id", "book_id"], name: "index_reading_sessions_on_app_user_id_and_book_id"
    t.index ["app_user_id", "read_date"], name: "index_reading_sessions_on_app_user_id_and_read_date"
    t.index ["book_id"], name: "index_reading_sessions_on_book_id"
  end

  create_table "recommends", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "grade_id", null: false, comment: "关联年级"
    t.string "name", null: false, comment: "推荐内容名称"
    t.integer "sn", default: 0, comment: "排序"
    t.boolean "status", default: true, comment: "状态: true发布/false草稿"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["grade_id", "sn"], name: "index_recommends_on_grade_id_and_sn"
    t.index ["grade_id"], name: "index_recommends_on_grade_id"
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

  create_table "suppliers", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", null: false, comment: "供应商名称"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_suppliers_on_name"
  end

  create_table "user_reading_daily_stats", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", comment: "用户阅读日统计表", force: :cascade do |t|
    t.bigint "app_user_id", null: false, comment: "用户ID"
    t.string "stat_date", null: false, comment: "统计日期 YYYY-MM-DD"
    t.integer "session_count", default: 0, null: false, comment: "当日阅读次数"
    t.integer "total_duration_seconds", default: 0, null: false, comment: "当日总阅读时长(秒)"
    t.integer "total_words_read", default: 0, null: false, comment: "当日总阅读字数"
    t.integer "books_read_count", default: 0, null: false, comment: "当日阅读书籍数"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id", "stat_date"], name: "index_user_reading_daily_stats_on_app_user_id_and_stat_date", unique: true
  end

  add_foreign_key "book_grades", "books"
  add_foreign_key "book_grades", "grades"
  add_foreign_key "books", "suppliers"
  add_foreign_key "catalogues", "books"
  add_foreign_key "category_sub_books", "books"
  add_foreign_key "category_sub_books", "category_subs"
  add_foreign_key "category_subs", "categories"
  add_foreign_key "compilation_books", "books"
  add_foreign_key "compilation_books", "compilations"
  add_foreign_key "compilation_categories", "categories"
  add_foreign_key "compilation_categories", "compilations"
  add_foreign_key "compilation_grades", "compilations"
  add_foreign_key "compilation_grades", "grades"
  add_foreign_key "content_groups", "recommends"
  add_foreign_key "contents", "content_groups"
  add_foreign_key "devices", "app_users"
  add_foreign_key "ebook_pages", "books"
  add_foreign_key "recommends", "grades"
end
