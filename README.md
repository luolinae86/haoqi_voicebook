# VoiceBook

> Rails 8.0.2 + Grape API + Sidekiq 异步电子书/有声书平台

## 项目简介

VoiceBook 是一个面向儿童阅读的内容管理平台，支持**电子书（PDF/EPUB）**、**有声书**、**视频**和**绘本**等多种内容类型。提供 API 接口供移动端调用，后端使用 Kamal 部署到阿里云。

## 技术栈

| 领域 | 技术 |
|------|------|
| 框架 | Rails 8.0.2, Ruby 3.3.0 |
| API | Grape 2.2 + Grape Entity |
| 数据库 | MySQL 8.0 (utf8mb4) |
| 缓存/队列 | Redis + Sidekiq 7.3 |
| 部署 | Kamal + Docker + kamal-proxy |
| 存储 | 阿里云 OSS |
| 渲染 | poppler-utils (pdftocairo) |
| 测试 | RSpec + FactoryBot + Webmock |

## 核心架构

### 内容模型

- **Book** — 图书主模型，支持 `ebook/audio/video/picture_book` 四种内容类型
- **EbookPage** — 电子书页面，存储 XHTML 富文本内容和图片块
- **Chapter** — 章节（用于纯文本电子书）
- **AudioAlbum / AudioEpisode** — 有声书专辑和分集
- **ReadingRecord / Bookmark / Bookshelf** — 用户阅读数据

### API 端点（Grape）

| 路径 | 说明 |
|------|------|
| `/api/books` | 图书列表 |
| `/api/books/:id` | 图书详情 |
| `/api/books/:id/pages` | 电子书页面清单 |
| `/api/books/:id/pages/:page_number` | 单页内容 |
| `/api/books/:id/pages/:page_number/html` | 单页 XHTML 内容 |
| `/api/books/:id/styles` | CSS 样式表（重定向到 OSS） |
| `/api/books/:id/toc` | 目录 |
| `/api/books/:id/chapters` | 章节列表 |
| `/api/books/import_pdf` | 上传并导入 PDF |
| `/api/books/import_epub` | 从 OSS 导入 EPUB |
| `/api/books/export_epub` | 从 OSS 上的 PDF 导出 EPUB |

### 电子书处理流程

#### PDF → EPUB 导出

1. `PdfImporter` — 从 PDF 提取正文行、标题行、目录、图片和字体元数据
2. `ExportPackage` — 写出中间页面包（manifest/pages/assets）
3. `EpubExporter` — 从页面包构建 EPUB
4. `EpubExportWorker` — 异步执行：下载 PDF → 解析 → 上传资源到 OSS → 打包 EPUB → 上传

#### EPUB 导入

1. `EpubImportWorker` — 从 OSS 下载 EPUB → 解压 → 解析 content.opf → 上传图片/CSS/Nav 到 OSS → 更新 XHTML 引用 → 保存页面到 DB → 重新打包 EPUB → 上传

#### 本地命令行工具

```bash
bin/ebook_worker /path/to/book.pdf \
  --title "书名" \
  --output-dir ~/Downloads/书名 \
  --epub-output ~/Downloads/书名.epub
```

## 部署

```bash
# 首次部署
kamal setup

# 日常部署
kamal deploy
```

### 部署关键信息

- **服务器**: `114.215.208.190`（阿里云 Ubuntu）
- **SSH 用户**: `root`（注意：不是 luolin，SSH 仅接受 root + id_rsa 密钥）
- **域名**: `api.zheliyuedu.cn`
- **Docker Registry**: `reg.ylb.im`
- **日志目录**: `/voicebook/log` 挂载到容器 `/rails/log`
- **Sidekiq 日志**: `log/sidekiq.log`（daily rotation）
- **Redis**: 阿里云 RDS（需设置 noeviction 策略，当前为 volatile-lru）

### 部署注意事项

1. SSH 密钥必须在 `~/.ssh/id_rsa` 且已加载到 ssh-agent（`ssh-add ~/.ssh/id_rsa`）
2. Kamal 远端构建，不需要从 Docker Hub 拉取基础镜像
3. 部署同时启动 web 和 worker 两个容器
4. kamal-proxy 负责 SSL 和健康检查

## 环境变量

生产环境通过 Kamal secret 注入：

- `DATABASE_PRD_*` — 阿里云 RDS MySQL 连接信息
- `ALIYUN_ACCESS_KEY_ID` / `ALIYUN_ACCESS_KEY_SECRET` — OSS 访问凭证
- `REDIS_URL` / `REDIS_PASSWORD` — Redis 连接信息
- `SECRET_KEY_BASE` — Rails 密钥

## 开发环境要求

```bash
# macOS
brew install mysql poppler

# Ubuntu / Debian
sudo apt install default-mysql-client poppler-utils

# Ruby 依赖
bundle install
bundle exec rake db:create db:migrate db:seed
```

## 测试

```bash
bundle exec rspec
bundle exec rspec spec/jobs/epub_import_worker_spec.rb  # 单个文件
bundle exec rspec spec/requests/api/v1/books_ebook_spec.rb
```

## 常用 Rake 任务

```bash
bundle exec rake ebooks:import PDF_PATH=/path/to/book.pdf
bundle exec rake ebooks:build_epub PACKAGE_DIR=/path/to/exported_package
```

## EPUB 格式说明

### EPUB 内部结构（已验证）

```
mimetype
META-INF/container.xml
OEBPS/
├── content.opf          # dc:title, manifest, spine（阅读顺序）
├── nav.xhtml            # 目录导航
├── styles/book.css      # 样式表
├── pages/page-NNNN.xhtml # 每页 XHTML
└── images/page-N.png     # 每页图片
```

### 固定布局 EPUB 特点

- 每页 XHTML 通过 viewport meta 声明尺寸（如 `width=857,height=1168`）
- 图片引用使用相对路径（`../images/page-1.png`）
- CSS 引用使用相对路径（`../styles/book.css`）
- `mimetype` 必须 STORE 无压缩且为 ZIP 第一个条目

## 注意事项

### rubyzip 2.x API 变更

- `Zip::COMPRESSION_METHOD_STORE`（下划线），不是 `Zip::COMPRESSION_METHOD::STORE`
- `Zip::File.open` 用于读取，`Zip::OutputStream.open` 用于写入
- `put_next_entry` 的第四个参数指定压缩方式

### Nokogiri XML 解析

- EPUB 的 container.xml 和 content.opf 使用命名空间，需要传 namespace 参数
- `doc.at_xpath("//xmlns:rootfile")` 用于默认命名空间
- `doc.at_xpath("//dc:title", "dc" => "http://purl.org/dc/elements/1.1/")`

### Gsub 替换注意事项

- 使用 `gsub(/pattern/, replacement)` 时，`Regexp.escape` 要在正则插值中使用
- 不要用 `%{}` 字符串 + `Regexp.escape` — 会把 `\` 当作字面量匹配
- 正确写法：`xhtml.gsub(/src="#{Regexp.escape(rel_path)}"/, "src=\"#{oss_url}\"")`

### 数据库约束

- `EbookPage.rich_content` 字段 NOT NULL，创建时必须传值（即使是空 Hash `{}`）
- `Book.title` 有 presence 验证，不能设为 nil
- `EbookPage.page_number` 在 book 范围内唯一

### 阿里云 OSS

- 使用 `aliyun-sdk` gem（版本 0.8），不是官方 SDK 的较新版本
- `AliyunOssService` 是项目封装的服务类，支持 `download_file` 和 `upload_file`
- OSS bucket 默认私有，需要签名 URL 才能直接访问

### Sidekiq

- Sidekiq 7 要求 job 参数为 JSON 原生类型（Hash with string keys）
- 使用 `sidekiq_options queue: "export", retry: 2`
- 日志持久化到 `log/sidekiq.log`（daily rotation）
- 当前 Redis maxmemory-policy 为 `volatile-lru`，建议改为 `noeviction`
