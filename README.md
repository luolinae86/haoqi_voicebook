# VoiceBook

## PDF 电子书

项目已支持将 PDF 导入为按页电子书数据，并同时导出：

- 页面包：`manifest.json + pages/*.json + assets/*`
- 最终 fixed-layout EPUB：`<书名>.epub`

推荐直接使用本地 worker，只需要传入一个 PDF 路径：

```bash
bin/ebook_worker /path/to/book.pdf \
  --title "书名" \
  --output-dir ~/Downloads/书名 \
  --epub-output ~/Downloads/书名.epub
```

运行后会得到：

- `~/Downloads/书名/manifest.json`
- `~/Downloads/书名/pages/page-0001.json ...`
- `~/Downloads/书名/assets/*`
- `~/Downloads/书名.epub`

详细说明见：

- `docs/pdf_import_export.md`

常用命令：

```bash
bin/ebook_worker /path/to/book.pdf
bundle exec rake ebooks:import PDF_PATH=/path/to/book.pdf
bundle exec rake ebooks:build_epub PACKAGE_DIR=/path/to/exported_package
```

默认会同时输出调试包目录和同名 `.epub` 文件。需要关闭 EPUB 时可用：

```bash
bin/ebook_worker /path/to/book.pdf --skip-epub
```

默认导出目录是 `~/Downloads/<书名>/`；如需把最终 EPUB 直接放到 Downloads 根目录，可显式传 `--epub-output ~/Downloads/<书名>.epub`。

当前标准链路是：

1. `PdfImporter` 从 PDF 提取正文行、标题行、目录、主图和字体元数据。
2. `ExportPackage` 写出稳定的中间页面包（`manifest/pages/assets`）。
3. `EpubExporter` 再从页面包反向构建 EPUB，而不是重新解析 PDF。
4. 如果提供源 PDF 路径，EPUB 会额外：
   - 提取 PDF 内嵌字体；
   - 将标题区域直接从 PDF 裁成图片，保证标题字形和 PDF 一致。
