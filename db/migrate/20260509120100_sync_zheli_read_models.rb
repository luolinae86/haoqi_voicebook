# frozen_string_literal: true

class SyncZheliReadModels < ActiveRecord::Migration[8.0]
  def up
    # Skip if already applied (books table has voicebook-specific columns and FK exists)
    return if column_exists?(:books, :content_type) && foreign_key_exists?(:ebook_pages, :books)

    remove_foreign_key :book_grades, :books, if_exists: true
    remove_foreign_key :chapters, :books, if_exists: true
    remove_foreign_key :compilation_books, :books, if_exists: true
    remove_foreign_key :category_sub_books, :books, if_exists: true
    remove_foreign_key :ebook_pages, :books, if_exists: true
    remove_foreign_key :audio_albums, :books, if_exists: true
    remove_foreign_key :bookmarks, column: :book_id, if_exists: true
    remove_foreign_key :bookmarks, column: :chapter_id, if_exists: true
    remove_foreign_key :blacklisted_books, column: :book_id, if_exists: true
    remove_foreign_key :bookshelves, column: :book_id, if_exists: true
    remove_foreign_key :bookshelves, column: :last_read_chapter_id, if_exists: true
    remove_foreign_key :app_users, column: :grade_id, if_exists: true

    # ---- Drop tables that will be recreated ----
    drop_table :ebook_pages, if_exists: true
    drop_table :bookmarks, if_exists: true
    drop_table :blacklisted_books, if_exists: true
    drop_table :books, if_exists: true

    # ---- Create new tables from zheli_read (idempotent) ----

    create_table :authors, if_not_exists: true do |t|
      t.string :name, null: false, comment: "作者名"
      t.string :head_img, null: false, comment: "头像"
      t.timestamps null: false
    end

    create_table :book_levels, if_not_exists: true do |t|
      t.string :name, limit: 50, null: false, comment: "等级名称"
      t.integer :sn, default: 0, null: false, comment: "序号"
      t.timestamps null: false
    end

    create_table :books, if_not_exists: true do |t|
      t.string :name, null: false, comment: "绘本名称"
      t.string :cover_image_url, comment: "绘本封面URL"
      t.bigint :category_id, comment: "绘本类型"
      t.json :themes, comment: "主题"
      t.bigint :supplier_id, comment: "归属供应商"
      t.bigint :book_level_id
      t.bigint :author_id
      t.bigint :compilations
      t.timestamps null: false
      t.index :category_id unless index_exists?(:books, :category_id)
      t.index :name unless index_exists?(:books, :name)
      t.index :supplier_id unless index_exists?(:books, :supplier_id)
    end

    create_table :categories, if_not_exists: true do |t|
      t.string :name, null: false
      t.integer :level, default: 1, null: false
      t.integer :sn, default: 0
      t.boolean :active, default: true
      t.timestamps null: false
      t.index :level unless index_exists?(:categories, :level)
    end

    create_table :category_subs, if_not_exists: true do |t|
      t.bigint :category_id, null: false, comment: "关联分类"
      t.string :name, null: false, comment: "子类名称"
      t.string :icon, comment: "图标URL"
      t.integer :sn, default: 0, comment: "排序"
      t.timestamps null: false
      t.index :category_id unless index_exists?(:category_subs, :category_id)
    end

    create_table :category_sub_books, if_not_exists: true do |t|
      t.bigint :category_sub_id, null: false
      t.bigint :book_id, null: false
      t.timestamps null: false
      unless index_exists?(:category_sub_books, [:book_id, :category_sub_id], name: "index_category_sub_books_on_book_id_and_category_sub_id")
        t.index [:book_id, :category_sub_id], unique: true, name: "index_category_sub_books_on_book_id_and_category_sub_id"
      end
      t.index :book_id unless index_exists?(:category_sub_books, :book_id)
      t.index :category_sub_id unless index_exists?(:category_sub_books, :category_sub_id)
    end

    create_table :chapters, if_not_exists: true do |t|
      t.bigint :book_id, null: false, comment: "所属绘本"
      t.string :name, null: false, comment: "章节名称"
      t.string :cover_image_url, comment: "章节封面图片URL"
      t.string :content_file_url, comment: "章节内容文件URL"
      t.string :content_file_name, comment: "章节内容文件名"
      t.string :content_file_type, comment: "内容文件类型 (epub/pdf/txt)"
      t.boolean :is_free, default: false, comment: "是否免费"
      t.boolean :is_published, default: false, comment: "是否上线"
      t.integer :sn, default: 0, comment: "排序"
      t.timestamps null: false
      t.index :book_id unless index_exists?(:chapters, :book_id)
    end

    create_table :compilations, if_not_exists: true do |t|
      t.string :name, null: false, comment: "合辑名称"
      t.string :banner_image_url, comment: "合辑banner图片URL (1500x932, <=500KB)"
      t.string :banner_image_name, comment: "合辑banner图片文件名"
      t.string :landscape_cover_url, comment: "横图封面URL (1125x540, <=500KB)"
      t.string :landscape_cover_name, comment: "横图封面文件名"
      t.string :portrait_cover_url, comment: "长方形封面URL (600x768, <=300KB)"
      t.string :portrait_cover_name, comment: "长方形封面文件名"
      t.string :square_cover_url, comment: "正方形封面URL (600x600, <=300KB)"
      t.string :square_cover_name, comment: "正方形封面文件名"
      t.string :editor_recommendation, limit: 15, comment: "编辑推荐语（15字以内）"
      t.string :publisher, comment: "出版社"
      t.integer :total_count, default: 0, comment: "合辑总集数"
      t.string :author, comment: "作者"
      t.json :tags, comment: "内容标签"
      t.string :intro_image_url, comment: "图片简介URL"
      t.string :intro_image_name, comment: "图片简介文件名"
      t.text :content_description, comment: "合辑简介（富文本/Markdown）"
      t.text :description, comment: "内容简介"
      t.timestamps null: false
      t.index :name, unique: true unless index_exists?(:compilations, :name)
    end

    create_table :compilation_books, if_not_exists: true do |t|
      t.bigint :compilation_id, null: false
      t.bigint :book_id, null: false
      t.timestamps null: false
      unless index_exists?(:compilation_books, [:compilation_id, :book_id], name: "index_compilation_books_on_compilation_id_and_book_id")
        t.index [:compilation_id, :book_id], unique: true, name: "index_compilation_books_on_compilation_id_and_book_id"
      end
      t.index :book_id unless index_exists?(:compilation_books, :book_id)
      t.index :compilation_id unless index_exists?(:compilation_books, :compilation_id)
    end

    create_table :compilation_categories, id: false, if_not_exists: true do |t|
      t.bigint :compilation_id, null: false
      t.bigint :category_id, null: false
      t.timestamps null: false
      unless index_exists?(:compilation_categories, [:compilation_id, :category_id], name: "index_compilation_categories_on_compilation_id_and_category_id")
        t.index [:compilation_id, :category_id], unique: true, name: "index_compilation_categories_on_compilation_id_and_category_id"
      end
      t.index :category_id unless index_exists?(:compilation_categories, :category_id)
      t.index :compilation_id unless index_exists?(:compilation_categories, :compilation_id)
    end

    create_table :compilation_grades, id: false, if_not_exists: true do |t|
      t.bigint :compilation_id, null: false
      t.bigint :grade_id, null: false
      t.timestamps null: false
      unless index_exists?(:compilation_grades, [:compilation_id, :grade_id], name: "index_compilation_grades_on_compilation_id_and_grade_id")
        t.index [:compilation_id, :grade_id], unique: true, name: "index_compilation_grades_on_compilation_id_and_grade_id"
      end
      t.index :compilation_id unless index_exists?(:compilation_grades, :compilation_id)
      t.index :grade_id unless index_exists?(:compilation_grades, :grade_id)
    end

    create_table :content_groups, if_not_exists: true do |t|
      t.bigint :recommend_id, null: false, comment: "关联年级"
      t.string :name, null: false, comment: "小组名称"
      t.string :group_type, null: false, comment: "小组类型"
      t.integer :sn, default: 0, comment: "排序"
      t.timestamps null: false
      t.index :recommend_id unless index_exists?(:content_groups, :recommend_id)
    end

    create_table :contents, if_not_exists: true do |t|
      t.bigint :content_group_id, null: false, comment: "关联内容分组"
      t.string :content_type, null: false, comment: "类型"
      t.string :img_url, comment: "图片链接"
      t.bigint :compilation_id, comment: "合辑信息"
      t.bigint :book_id, comment: "单本信息"
      t.bigint :recommend_id, comment: "推荐信息"
      t.bigint :author_id, comment: "作者信息"
      t.integer :sn, default: 0, comment: "排序"
      t.timestamps null: false
      t.index :content_group_id unless index_exists?(:contents, :content_group_id)
    end

    create_table :grades, if_not_exists: true do |t|
      t.string :group_name, limit: 8
      t.string :name, limit: 16
      t.string :description, limit: 32
      t.timestamps null: false
    end

    create_table :book_grades, id: false, if_not_exists: true do |t|
      t.bigint :book_id, null: false
      t.bigint :grade_id, null: false
      t.timestamps null: false
      unless index_exists?(:book_grades, [:book_id, :grade_id], name: "index_book_grades_on_book_id_and_grade_id")
        t.index [:book_id, :grade_id], unique: true, name: "index_book_grades_on_book_id_and_grade_id"
      end
      t.index :book_id unless index_exists?(:book_grades, :book_id)
      t.index :grade_id unless index_exists?(:book_grades, :grade_id)
    end

    create_table :recommends, if_not_exists: true do |t|
      t.bigint :grade_id, null: false, comment: "关联年级"
      t.string :name, null: false, comment: "推荐内容名称"
      t.integer :sn, default: 0, comment: "排序"
      t.boolean :status, default: true, comment: "状态: true发布/false草稿"
      t.timestamps null: false
      t.index :grade_id unless index_exists?(:recommends, :grade_id)
      unless index_exists?(:recommends, [:grade_id, :sn], name: "index_recommends_on_grade_id_and_sn")
        t.index [:grade_id, :sn], name: "index_recommends_on_grade_id_and_sn"
      end
    end

    create_table :suppliers, if_not_exists: true do |t|
      t.string :name, null: false, comment: "供应商名称"
      t.timestamps null: false
      t.index :name unless index_exists?(:suppliers, :name)
    end

    create_table :bookmarks, if_not_exists: true do |t|
      t.integer :app_user_id, null: false, comment: "用户ID"
      t.integer :book_id, null: false, comment: "图书ID"
      t.integer :chapter_id, comment: "章节ID"
      t.decimal :position, precision: 5, scale: 2, default: 0.0, comment: "位置(%)"
      t.timestamps null: false
      t.index :app_user_id unless index_exists?(:bookmarks, :app_user_id)
      t.index :book_id unless index_exists?(:bookmarks, :book_id)
    end

    create_table :blacklisted_books, if_not_exists: true do |t|
      t.integer :parental_control_id, null: false, comment: "家长管控ID"
      t.integer :book_id, null: false, comment: "图书ID"
      t.timestamps null: false
      unless index_exists?(:blacklisted_books, [:parental_control_id, :book_id], name: "index_blacklisted_books_on_parental_control_id_and_book_id")
        t.index [:parental_control_id, :book_id], unique: true, name: "index_blacklisted_books_on_parental_control_id_and_book_id"
      end
      t.index :parental_control_id unless index_exists?(:blacklisted_books, :parental_control_id)
      t.index :book_id unless index_exists?(:blacklisted_books, :book_id)
    end

    # ---- Ensure compilations has portrait/square cover columns (idempotent) ----
    unless column_exists?(:compilations, :portrait_cover_url)
      add_column :compilations, :portrait_cover_url, :string, comment: "长方形封面URL (600x768, <=300KB)"
    end
    unless column_exists?(:compilations, :portrait_cover_name)
      add_column :compilations, :portrait_cover_name, :string, comment: "长方形封面文件名"
    end
    unless column_exists?(:compilations, :square_cover_url)
      add_column :compilations, :square_cover_url, :string, comment: "正方形封面URL (600x600, <=300KB)"
    end
    unless column_exists?(:compilations, :square_cover_name)
      add_column :compilations, :square_cover_name, :string, comment: "正方形封面文件名"
    end

    # ---- Add voicebook-specific columns to books (idempotent) ----
    voicebook_book_columns = {
      content_type: [:integer, { default: 0, null: false, comment: "类型：0-电子书 1-有声 2-视频 3-绘本" }],
      is_free: [:boolean, { default: false, null: false, comment: "是否免费" }],
      is_vip: [:boolean, { default: false, null: false, comment: "是否VIP" }],
      grade_id: [:bigint, { comment: "年级ID" }],
      play_count: [:integer, { default: 0, null: false, comment: "播放/阅读次数" }],
      word_count: [:integer, { default: 0, null: false, comment: "字数" }],
      rating: [:decimal, { precision: 3, scale: 1, default: "0.0", comment: "评分" }],
      status: [:integer, { default: 0, null: false, comment: "状态：0-草稿 1-已发布 2-已下架" }],
      isbn: [:string, { comment: "ISBN" }],
      page_count: [:integer, { default: 0, null: false, comment: "电子书总页数" }],
      import_status: [:integer, { default: 0, null: false, comment: "电子书导入状态" }],
      source_pdf_filename: [:string, { comment: "源 PDF 文件名" }],
      source_pdf_path: [:string, { comment: "源 PDF 存储路径" }],
      ebook_checksum: [:string, { comment: "源 PDF 校验值" }],
      imported_at: [:datetime, { comment: "导入完成时间" }],
      import_error_message: [:text, { comment: "导入失败信息" }],
      epub_oss_key: [:string, { comment: "EPUB 文件 OSS 路径" }],
      epub_oss_url: [:string, { comment: "EPUB 文件公网 URL" }],
      epub_export_status: [:integer, { default: 0, comment: "EPUB 导出状态：0-未导出 1-导出中 2-已完成 3-失败" }],
      epub_export_error: [:text, { comment: "EPUB 导出失败原因" }],
      styles_oss_url: [:string, { comment: "book.css 的 OSS URL" }],
      nav_oss_url: [:string, { comment: "nav.xhtml 的 OSS URL" }],
    }
    voicebook_book_columns.each do |col_name, (col_type, opts)|
      unless column_exists?(:books, col_name)
        add_column :books, col_name, col_type, **opts
      end
    end
    add_index :books, :import_status unless index_exists?(:books, :import_status)
    add_index :books, :status unless index_exists?(:books, :status)

    # ---- Recreate ebook_pages table (voicebook-specific, idempotent) ----
    create_table :ebook_pages, if_not_exists: true, comment: "电子书页面表" do |t|
      t.bigint :book_id, null: false, comment: "图书ID"
      t.integer :page_number, null: false, comment: "页码"
      t.decimal :page_width, precision: 8, scale: 2, null: false, comment: "页面宽度(pt)"
      t.decimal :page_height, precision: 8, scale: 2, null: false, comment: "页面高度(pt)"
      t.text :plain_text, comment: "页面纯文本"
      t.json :rich_content, null: false, comment: "页面富文本块"
      t.integer :word_count, default: 0, null: false, comment: "字数"
      t.integer :block_count, default: 0, null: false, comment: "块数量"
      t.integer :image_count, default: 0, null: false, comment: "图片数量"
      t.string :xhtml_content, comment: "页面 XHTML 内容"
      t.timestamps
      t.index [:book_id, :page_number], unique: true, name: "index_ebook_pages_on_book_id_and_page_number" unless index_exists?(:ebook_pages, [:book_id, :page_number])
      t.index :book_id unless index_exists?(:ebook_pages, :book_id)
    end
    add_foreign_key :ebook_pages, :books unless foreign_key_exists?(:ebook_pages, :books)

    # ---- Update column types (safe to run multiple times) ----
    col = connection.columns(:app_users).find { |c| c.name == "grade_id" }
    change_column :app_users, :grade_id, :bigint if col && col.sql_type !~ /bigint/i
    col = connection.columns(:bookshelves).find { |c| c.name == "book_id" }
    change_column :bookshelves, :book_id, :bigint if col && col.sql_type !~ /bigint/i
    col = connection.columns(:bookshelves).find { |c| c.name == "last_read_chapter_id" }
    change_column :bookshelves, :last_read_chapter_id, :bigint if col && col.sql_type !~ /bigint/i

    # ---- Add foreign keys (skip if already exist) ----
    table_fks = [
      [:book_grades, :books],
      [:book_grades, :grades],
      [:books, :suppliers],
      [:category_sub_books, :books],
      [:category_sub_books, :category_subs],
      [:category_subs, :categories],
      [:chapters, :books],
      [:compilation_books, :books],
      [:compilation_books, :compilations],
      [:compilation_categories, :categories],
      [:compilation_categories, :compilations],
      [:compilation_grades, :compilations],
      [:compilation_grades, :grades],
      [:content_groups, :recommends],
      [:contents, :content_groups],
      [:recommends, :grades],
    ]

    table_fks.each do |from_table, to_table|
      unless foreign_key_exists?(from_table, to_table)
        add_foreign_key from_table, to_table
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
