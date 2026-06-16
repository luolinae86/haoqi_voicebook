---
name: EPUB import 同 spine 多 TOC 条目 start_page_number 唯一化
description: BookEpubImportWorker 修复同一 XHTML 文件被多个 TOC 条目指向时，每个 catalogue 分配独立 start_page_number
type: project
---

**问题**: EPUB 中多个 TOC 条目可能指向同一个 spine XHTML 文件（如"第期5"和"太阳史诗——七月"指向同一文件），旧逻辑给它们分配相同的 `start_page_number`，导致前端阅读分页混乱。

**修复**: `app/jobs/book_epub_import_worker.rb` 中为同一 spine 的每个 TOC 条目分配递增的 `page_number`，每个 catalogue 和 ebook_page 都有独立的 `start_page_number`。

**字数分配**: 同一 spine 的字数只计入第一个 catalogue/ebook_page，后续共享文件的章节 `word_count: 0`，避免重复计算。

**验证**: `catalogues.group_by(&:start_page_number).select { |k, v| v.size > 1 }` 应返回空。
