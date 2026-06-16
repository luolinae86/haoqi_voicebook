---
name: Grape namespace 统一鉴权用 before 块
description: Grape namespace 下所有端点都需 auth_user 时，用 before 块统一鉴权，不在每个 endpoint 内重复调用
type: feedback
---

Grape namespace 下每个接口都需要鉴权时，应在 namespace 内使用 `before do auth_user end` 统一处理，而非在每个 endpoint 内部重复写 `auth_user`

**Why:** 每个端点重复写 `auth_user` 是冗余代码，维护成本高且容易遗漏

**How to apply:**
```ruby
namespace :parental do
  before do
    auth_user
  end

  # endpoint 内不再需要 auth_user
  post :setup do
    # 直接使用 current_user
  end
end
```
- `before` 块在 namespace 内每个请求执行前运行
- endpoint 内部直接使用 `current_user`，无需再调 `auth_user`
- 未登录时 `before` 块直接返回错误响应，不会进入 endpoint 逻辑
