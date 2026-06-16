---
name: book 返回必须包含三个字段
description: 所有返回 book 的接口必须包含 content_description, category_subs, supplier_name
type: feedback
---

所有序列化 book 的地方必须返回以下三个字段：
- `content_description` — 内容简介
- `category_subs` — 二级分类数组 `[{ id, name, sn }]`
- `supplier_name` — 出版社名称

已在以下三处统一：
1. `app/entities/book.rb` — Grape Entity 全局使用
2. `app/controllers/api/home/home_helpers.rb` — home_helpers 的 serialize_book
3. `app/entities/rank_content_entity.rb` — 排行榜内容中的 book
