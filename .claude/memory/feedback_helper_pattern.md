---
name: helper 剥离方法约定
description: 从 Grape API 类中剥离方法时，创建独立 helper 文件到 app/controllers/api/helpers/v4/ 下，通过 helpers Api::Helpers::V4::XxxHelpers 引入
type: feedback
---

**规则：** 将 Grape API endpoint 中的辅助方法剥离到 `app/controllers/api/helpers/v4/` 下的独立 helper 文件中，在 API 类中用 `helpers Api::Helpers::V4::XxxHelpers` 引入。

**Why：** 用户指定了项目的 helper 目录和引入方式，这是 Grape 的 helpers DSL 标准用法，比 include 更符合 Grape 规范。

**How to apply：**
- **先看当前 API 类所在的版本目录**（v1/v2/v3/v4 等），决定 helper 放到对应的 `app/controllers/api/helpers/{version}/` 目录下
- 命名如 `scan_bar_helpers.rb`（复数形式）
- 模块名使用 `Api::Helpers::{Version}::XxxHelpers`（如 `Api::Helpers::V4::ScanBarHelpers`）
- 模块内必须包含：
  ```ruby
  extend Grape::API::Helpers
  extend Api::Helpers::CommonHelpers
  ```
  这样才能引用 Grape helpers 和公共方法（如 `number_string`、`api_post_request` 等）
- 在 Grape API 类中用 `helpers Api::Helpers::{Version}::XxxHelpers` 引入
- 参考：`app/controllers/api/v4/order.rb` 中 `helpers Api::Helpers::V4::OrderHelpers`