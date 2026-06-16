---
name: Grape API helpers 必须独立为模块文件
description: voicebook 项目中 Grape API 的 helpers 不能写在 helpers do end 块内，必须抽取到与 API 同目录的独立 helper 模块文件中
type: feedback
---

**规则**：Grape API 的 helpers 必须独立到 `app/controllers/api/模块名/模块_helpers.rb` 文件中，通过 `helpers Api::模块名::模块Helpers` 引入，禁止在 API 类内使用 `helpers do ... end` 块。

**Why:** 用户明确指出 `helpers do ... end` 写到 API 类内部不符合规范，应以 `app_users/app_user_api.rb` 的风格为准 — 每个模块有独立的 helpers 模块文件（如 `app_user_helpers.rb`），在 API 中通过 `helpers Api::AppUsers::AppUserHelpers` 引入。

**How to apply:** 新增 Grape API 模块时，如有共享方法，创建 `app/controllers/api/xxx/xxx_helpers.rb`，定义为 `module Api::Xxx::XxxHelpers`，继承 `extend Grape::API::Helpers`，然后在 API 类中 `helpers Api::Xxx::XxxHelpers` 引入。参考 `app/controllers/api/app_users/app_user_helpers.rb`。
