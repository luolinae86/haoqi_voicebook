---
name: Grape API 重构为 Service 模式
description: 从 Grape API endpoint 提取复杂业务逻辑到 app/services/ 下的独立 Service 类，endpoint 只保留鉴权、调用、响应
type: feedback
---

当 Grape API endpoint 代码行数过多（超过 15 行业务逻辑）时，应提取到 `app/services/` 下独立 Service 类

**Why:** endpoint 内写太多逻辑导致难以测试、难以复用、可读性差

**How to apply:**
- endpoint 只保留：auth → 调用 Service → present 响应 → rescue 错误
- Service 类放在 `app/services/<domain>/<action>_service.rb`，使用 `initialize + call` 模式
- 校验失败抛自定义 Error（如 `ImportService::Error`），endpoint 层 `rescue` 后转 `error_pop_resp`
- URI 解析等重复操作在 Service 中用 memoized 方法（`@uri ||= ...`）避免重复计算
- Worker 派发也封装在 Service 中，endpoint 不直接引用 Worker
