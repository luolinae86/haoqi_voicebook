---
name: Grape API 复杂逻辑优先放 helpers 而非 Service
description: Grape API endpoint 业务逻辑提取时，优先放到对应 app/helpers/ 下的 helper 模块，而非 app/services/
type: feedback
---

Grape API endpoint 业务逻辑过多时，**优先提取到对应的 `app/helpers/` helper 模块**，而不是创建独立 Service

**Why:** 用户偏好，helper 与 API 耦合更紧，结构更扁平

**How to apply:**
- 每个 `*_api.rb` 对应一个 `*_helpers.rb`（如 `book_api.rb` → `book_helpers.rb`）
- helper 放在 `app/helpers/` 或 `app/controllers/api/<namespace>/` 下
- 用 `extend Grape::API::Helpers` 声明
- endpoint 中调用 helper 方法：`submit_import_task(book, file_url)`
- 如果逻辑涉及跨多个 API 或需要独立生命周期，才考虑放到 `app/services/`
