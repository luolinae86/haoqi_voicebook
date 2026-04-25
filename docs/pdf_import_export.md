# PDF 导入导出说明

## 目标

把 PDF 电子书转换成适合 APP 阅读的页面结构：

- 每页只有一个 `text` 字段，便于前端直接渲染整页文本。
- 每一行文本都保留换行，并在文本前加上角色标记：
  - `[TITLE]` 标题行
  - `[BODY]` 正文行
- 图片只保留每页最上方的主图，过滤右侧装饰图。
- 复杂图片页会走**页级渲染裁剪**，避免只拿到 PDF 底层某一层图片。
- 侧边栏文字不并入整页 `text`，避免干扰正文阅读。
- 每一行文本保留字体元数据，供前端尽量还原字号/字体风格。
- 每一页都带所属目录信息，便于前端显示“当前读到哪一章”。
- 可导出为本地调试目录，包含页面 JSON 和图片资源。

## 标准工作流（当前推荐）

默认推荐只记住这一条命令：

```bash
bin/ebook_worker /绝对路径/你的书.pdf \
  --title "书名" \
  --output-dir ~/Downloads/书名 \
  --epub-output ~/Downloads/书名.epub
```

它会一次性完成：

1. 导入 PDF。
2. 生成中间页面包：`manifest.json + pages/*.json + assets/*`。
3. 再根据页面包构建 fixed-layout EPUB。

输出结果：

```text
~/Downloads/书名/
├── manifest.json
├── pages/
│   ├── page-0001.json
│   └── ...
└── assets/
    ├── 1-image_1.png
    └── ...

~/Downloads/书名.epub
```

如果你已经有现成页面包，只想重建 EPUB：

```bash
bundle exec rake ebooks:build_epub \
  PACKAGE_DIR=/path/to/exported_package \
  SOURCE_PDF_PATH=/path/to/original.pdf \
  EPUB_OUTPUT=/path/to/book.epub
```

这里的 `SOURCE_PDF_PATH` 很重要：  
它不仅用于字体提取，也用于把章节标题直接从 PDF 原页裁成标题图片，保证标题字形、笔画和 PDF 一致。

## 当前实现

### 1. 导入

入口：

- API：`POST /api/books/import_pdf`
- Rake：`bundle exec rake ebooks:import PDF_PATH=/path/to/book.pdf`
- 本地 worker：`bin/ebook_worker /path/to/book.pdf`

核心类：

- `Ebook::PdfImporter`
- `Ebook::PdfPageReceiver`
- `Ebook::ImageExporter`
- `Ebook::ExportPackage`
- `Ebook::EpubExporter`
- `Ebook::LocalExportWorker`

### 2. 页面存储

`ebook_pages` 表保存：

- `plain_text`：整页文本，带角色标记和换行
- `rich_content.text`：与 `plain_text` 一致
- `rich_content.lines`：逐行结构化信息
- `rich_content.images`：筛选后的主图列表
- `rich_content.directory`：当前页所属目录/章节

页面 JSON 结构示例：

```json
{
  "page_number": 3,
  "page_width": "428.03",
  "page_height": "612.28",
  "word_count": 330,
  "image_count": 1,
  "text": "[TITLE] 发光的徽章\n[BODY] 杨歌，小心！\n[BODY] ...\n",
  "lines": [
    {
      "id": "line-3-1",
      "role": "heading",
      "text": "发光的徽章",
      "marker": "[TITLE]",
      "text_with_role": "[TITLE] 发光的徽章\n",
      "style": {
        "font_family": "FZSSK--GBK1-0",
        "font_name": "FESXEA+FZSSK--GBK1-0",
        "font_weight": "normal",
        "font_style": "normal",
        "font_size_pt": 11.5
      }
    }
  ],
  "images": [
    {
      "id": "image-3-1",
      "role": "hero_image",
      "image_url": "/system/ebooks/book_1/page_3/image_1.png",
      "source_filter": "QuartzPageRender"
    }
  ],
  "directory": {
    "title": "一 发光的徽章",
    "toc_page_number": 1,
    "start_page_number": 3,
    "level": 1,
    "source": "toc"
  }
}
```

## 本地调试方式

### 方式一：worker（直接传入 PDF 路径）

```bash
bin/ebook_worker /Users/luolin/Downloads/生肖守护神book.pdf \
  --title "生肖守护神book" \
  --output-dir /Users/luolin/Downloads/生肖守护神book \
  --epub-output /Users/luolin/Downloads/生肖守护神book.epub
```

说明：

- 第一个位置参数就是 **PDF 文件路径**。
- 不传 `--title` 时，默认使用 PDF 文件名作为书名。
- 不传 `--output-dir` 时，默认导出到 `~/Downloads/<书名>`。
- 默认会额外生成 `~/Downloads/<书名>/<书名>.epub`。
- 如需把最终 EPUB 直接放到 Downloads 根目录，可显式传 `--epub-output ~/Downloads/<书名>.epub`。
- 如只想导出调试目录，可加 `--skip-epub`。
- 生成 EPUB 时，当前实现会**先写出 `manifest.json + pages + assets`，再从这份导出包反向构建 EPUB**。
- 生成 EPUB 时会优先从**源 PDF 内嵌字体**里提取真实字体文件，再打进 `EPUB/fonts/*`，尽量保持和 PDF 一样的字形。
- 如果能拿到源 PDF，章节标题会优先直接从 PDF 页面按标题 bbox 裁成图片，并在 EPUB 中作为标题层显示；正文仍保持文字层。

### 方式二：Rake

```bash
bundle exec rake ebooks:import \
  PDF_PATH=/Users/luolin/Downloads/生肖守护神book.pdf \
  TITLE=生肖守护神book \
  OUTPUT_DIR=/Users/luolin/Downloads/生肖守护神book
```

### 方式三：根据现有导出包重建 EPUB

```bash
bundle exec rake ebooks:build_epub \
  PACKAGE_DIR=/Users/luolin/Downloads/生肖守护神book \
  SOURCE_PDF_PATH=/Users/luolin/Downloads/生肖守护神book.pdf
```

这条命令只读取：

- `manifest.json`
- `pages/*.json`
- `assets/*`

不会重新导入 PDF，也不会改动现有 `pages` / `assets` 规则。

如果 `manifest.json` 里已经带有 `book.source_pdf_path`，可以不额外传 `SOURCE_PDF_PATH`；  
如果是旧导出包，建议显式传入 `SOURCE_PDF_PATH`，这样 EPUB 才能把 PDF 原始字体内嵌进去。

导出目录结构：

```text
Downloads/生肖守护神book/
├── manifest.json
├── pages/
│   ├── page-0001.json
│   └── ...
└── assets/
    ├── 1-image_1.png
    └── ...
├── 生肖守护神book.epub
```

## 注意事项

1. **扫描版 PDF**
   - 如果 PDF 没有文本层，`pdf-reader` 提取不到正文，页面 `text` 可能为空。
   - 这种情况需要后续接 OCR。

2. **图片过滤**
   - 当前规则会优先保留顶部、靠近标题的主图/logo。
   - 左右两侧窄而高的装饰条会被降权或过滤。
   - 小尺寸 `ImageMask` 会按“疑似文字蒙版”处理，避免把文字误识别成图片。

3. **换行保留**
   - 当前输出按“视觉行”保留换行，不做 HTML 合并。
   - 前端可直接按 `\n` 切分显示。

4. **导出目录覆盖**
   - 本地 worker / Rake 每次都会清空目标输出目录后再导出。
   - 这样可以避免旧图片和旧页面 JSON 残留。

5. **角色标记**
   - `[TITLE]` / `[BODY]` 是面向前端的稳定约定。
   - 比 HTML 更轻，适合字号缩放、TTS、搜索高亮和离线缓存。

6. **图片格式**
   - 普通 PDF 图片对象（如 JPEG/JPX）会优先直接导出原始 XObject，避免小 logo 被页级裁剪错位。
   - `ImageMask` / 复合图层页才走 Quartz 页级渲染裁剪，并做上下方向校正。
   - 对整页 Quartz 渲染图片，会额外带一段右侧 bleed，避免原 PDF 中靠右内容在导出源图时被裁掉。
   - 这样既能保住真实 logo 资源，又能处理整页漫画/扫描图。

7. **字体还原**
   - 当前 fixed-layout EPUB 会优先从源 PDF 中提取内嵌的 `FontFile/FontFile2/FontFile3` 字体流，并写入 `EPUB/fonts/*`。
   - 文本层会按 `font_name -> font_family` 的顺序绑定到对应 `@font-face`，比单纯依赖系统字体回退更接近 PDF 原稿。
   - 一旦命中 PDF 内嵌字体，EPUB 会直接使用 PDF 原始 `font_size_pt`，不再额外缩小字号。
   - 如果构建 EPUB 时拿不到源 PDF，则仍会退回到 `font_family` + 系统默认字体，版式大概率还能保持，但字形一致性会下降。

8. **目录归属**
   - 优先从 PDF 前置目录页提取章节并映射正文页。
   - 如果 PDF 没有目录页，会回退到正文大标题分段。

## 为什么 PDF 转富文本电子书，最好的方式不是直接转 HTML

更推荐的方式是：

**PDF -> 行级结构化文本 + 主图资源 + 页面元数据**

原因：

1. **更适合阅读器**
   - 前端最需要的是可缩放文本、稳定换行、页面跳转。
   - 直接 HTML 往往携带大量定位样式，阅读体验反而差。

2. **更容易跨端统一**
   - iOS、Android、小程序对富文本支持差异大。
   - `text + lines + images + bbox` 比 HTML 更容易统一渲染。

3. **更方便做二次能力**
   - 朗读
   - 搜索
   - 摘录
   - 高亮
   - 字体缩放
   - 夜间模式

4. **更容易容错**
   - PDF 原始版式经常有装饰图、页眉、页脚、浮动元素。
   - 先转成结构化中间层，再给前端渲染，稳定性更高。

## 当前最佳 EPUB 方案

对 **未转曲 PDF（有文本层）** 和 **已转曲 / 扫描 PDF（文本层较弱）**，当前最稳的方案不是直接转纯 HTML，而是导出成**页面包驱动的混合型 fixed-layout EPUB**。

### 1. 总体原则

1. **先生成页面包，再生成 EPUB**
   - 先稳定输出 `manifest.json + pages/*.json + assets/*`
   - EPUB 只从页面包反向构建
   - 这样能保证中间层和最终书一致，避免两套解析逻辑分叉

2. **正文尽量保留为文字层**
   - 方便搜索、TTS、摘录、字号缩放
   - 行级 `bbox / font / align / marker` 都要保留

3. **标题优先保留 PDF 原视觉**
   - 当 `source_pdf_path` 可用时，标题优先直接按标题 bbox 从 PDF 原页裁图
   - EPUB 页面里显示标题图片层，而不是依赖字体回退模拟标题

4. **图片与文本分层**
   - 主图 / 整页图走图片层
   - 正文走文字层
   - 标题根据可用条件走标题图片层或标题文字层

### 2. 当前稳定规则

#### 页面级规则

- 一页 PDF 对应一个 XHTML 页面
- 普通文本页使用**阅读器安全外框**
  - 保持 PDF 原始页面高度
  - 扩大 viewport 宽度 / frame 宽度
  - 让阅读器按宽度适配时，整页自动缩小一点，从而完整显示页底最后一行和页码
- 只有整页 Quartz 渲染图片页才扩宽整页图片显示宽度

#### 文本层规则

- 文本层统一使用**单行渲染**
- 默认直接沿用页面包中的：
  - `bbox.left`
  - `bbox.width`
  - `font_size_pt`
  - `align`
- 文本层使用 `overflow: visible`
- 文本框只允许向右增加必要的渲染缓冲区，不能改坏左边起点、缩进和字号

#### 字体规则

- 优先从源 PDF 提取内嵌字体并打入 `EPUB/fonts/*`
- 文本层优先按 `font_name` 精确映射 `@font-face`
- 命中 PDF 内嵌字体后，直接使用 PDF 原字号
- 只有无法命中内嵌字体时，才允许回退到 `font_family + sans-serif`

#### 标题规则

- 标题先做专用清洗：
  - 保留章节序号
  - 清理重复序号污染，例如 `十十二生肖的秘密 -> 十二生肖的秘密`
- 有源 PDF 时：
  - 标题优先输出为 PDF 裁图层
  - 同位置标题文字层不再重复输出
- 标题与右侧配图距离过近时：
  - 优先右移配图
  - 只有无法安全避让时，才隐藏标题文字层

#### 污染清理规则

- 过滤完全落在图片里的文字层
- 过滤左侧装饰图拆出来的单字母噪声
- 过滤左侧窄列的整行脏字，如 `IK……`
- 对污染前缀行（如 `H...` / `N...` / `IK...` / `D...`）：
  - 先清前缀
  - 再修复 `left / width / align`
- 对右侧标题碎片污染（如 `六自古英` / `八令人尴` / `九武术高` / `二十尾六`）：
  - 先按当前章节标题碎片清理尾部污染
  - 再按页宽重算 `width / right`
  - 仍越界时继续按正文字符宽度模型裁掉尾部污染
- 对正文尾部误混入章节序号（如 `看了二` / `…我呢？十一`）：
  - 结合下一行续写关系做清理
- 对行尾孤立污染字符（如 `闪光灯『`）：
  - 按上下文清理

### 3. 生成完成后的自动巡检要点

生成 EPUB 后，至少要检查以下项目：

1. **标题**
   - 标题页如果命中标题裁图层，不能再同时出现同位置标题文字层
   - 标题不能有重复字、污染字、缺字
   - 标题不能压住右侧图片

2. **正文**
   - 正文层不得存在左侧脏前缀
   - 正文层不得存在右侧标题碎片
   - 任意正文层都不得出现 `left + width > page_width`
   - 靠近右边界的有效文本层，其宽度可以略大于原始 bbox，但不能越页

3. **字体**
   - EPUB 内嵌字体文件数量应和 PDF 实际使用字体集合基本一致
   - 正文层应尽量命中 `PDFEmbed-*` 字体族
   - 命中 `PDFEmbed-*` 的文本层，其 `font-size` 必须与页面包中的 `font_size_pt` 一致

4. **页底**
   - 页底最后一行和页码必须在目标阅读器中真正可见
   - 不能只是在 XHTML 里“存在”

### 4. 最近这条链路里踩过的坑

1. **不能靠增加页面高度解决页底丢行**
   - 某些 fixed-layout 阅读器会按宽度适配，但不会因为页面更高就自动把整页缩小
   - 结果是 XHTML 里有最后一行，阅读器里却直接裁底
   - 当前稳定解法：保持原始页面高度，给普通文本页增加更宽的安全外框

2. **标题字体只靠内嵌字体还不够**
   - 即使命中 PDF 内嵌字体，标题的笔画、字距、子集字形仍可能和 PDF 不完全一致
   - 当前优先解法：标题直接按 PDF bbox 裁图

3. **标题污染不能套用正文规则**
   - `十十二生肖的秘密` 不是正文 carry-over，而是标题本身重复序号
   - 必须单独用目录标题 / 章节序号做标题清洗

4. **标题压图不一定要等到 bbox 明显相交**
   - 有些章节页虽然只是轻微擦边，但视觉上已经像“标题压图”
   - 当前规则是先右移配图留出安全间距

### 5. 遇到问题时的标准排错顺序

不要一上来就同时改 importer 和 exporter。标准排错顺序是：

1. **先看 PDF 原页**
   - 先确认原 PDF 是否真的有这行字 / 这个标题 / 这张图

2. **再看页面包 `pages/*.json`**
   - 如果 JSON 里已经错了，问题在 `PdfImporter` 或导出清洗阶段
   - 如果 JSON 正常，而 EPUB 错了，问题在 `EpubExporter`

3. **再看 EPUB XHTML**
   - 如果 XHTML 里文本 / 标题 / 页码已经存在，但阅读器里看不到，优先怀疑：
     - fixed-layout viewport / frame
     - reader clipping
     - 标题层和图片层叠放顺序

4. **最后再看阅读器截图**
   - 阅读器截图主要用于确认“可见性问题”
   - 不能只靠截图判断文本提取层是否正确

5. **修改时遵守这个原则**
   - 能只改标题层，就不要动正文层
   - 能只改 EPUB 层，就不要回退去动 importer
   - 只有当 `pages/*.json` 已经脏了，才回头修 importer / 页面包生成

### 6. 为什么这套方案当前最稳

它能同时兼顾：

- 阅读器兼容性
- 字号缩放
- 搜索 / TTS 的可扩展性
- 转曲 PDF 的视觉保真

## 推荐的长期方案

如果后续要把 PDF 电子书做成正式产品，建议采用三层结构：

1. **源文件层**
   - 原始 PDF

2. **中间结构层**
   - 页面
   - 行
   - 图片
   - 角色标记
   - bbox

3. **阅读层**
   - APP 按页请求
   - 文本字号独立缩放
   - 图片固定比例显示

这样后续要接 OCR、章节识别、AI 摘要、朗读、搜索时，都不需要推翻现有数据结构。
