---
name: Ruby 代码风格偏好
description: 用户使用 Ruby 时的代码风格偏好
type: feedback
---

**风格规则：**
- 布尔值判断用 `.present?` 而不是 `== true`，例如 `if params[:is_global].present?`
- 严格遵守 RuboCop 规范

**Why:** 用户更倾向于 Ruby 惯用写法，认为 `.present?` 比 `== true` 更符合 Ruby 风格

**How to apply:**
- 编写 Ruby 代码时，布尔判断优先使用 `.present?` 或 `.blank?`
- 代码完成后确保符合 RuboCop 规范（无 Layout/Metrics 等警告）
