---
name: zheli_read 测试环境部署问题记录
description: 2026-05-11 修复的测试环境部署问题汇总
type: project
---

## 2026-05-11 修复的问题

### 1. OSS 上传超时
- **现象**: `Net::OpenTimeout` 连接 `zheli.oss-cn-beijing-internal.aliyuncs.com` 超时 60s
- **原因**: `secrets.staging` 中 `ALIYUN_OSS_INTERNAL=true`，Docker 容器不在阿里云 VPC 内，内网端点不可达
- **修复**: `secrets.staging` 中将 `ALIYUN_OSS_INTERNAL` 改为 `false`

### 2. 数据库迁移失败
- **现象**: `Table 'zheli_read_staging.users' doesn't exist`
- **原因**: 3 个迁移文件在 `grades` 表创建前就声明了外键
- **修复**:
  - `20240401000006_create_books.rb` — `book_grades.grade_id` 去掉 `foreign_key: true`
  - `20240401000009_create_compilations.rb` — `compilation_grades.grade_id` 去掉 `foreign_key: true`
  - `20260328000003_create_recommends.rb` — `recommends.grade_id` 去掉 `foreign_key: true`

### 3. Sidekiq 崩溃
- **现象**: `undefined method 'info' for an instance of File`
- **原因**: `config/initializers/sidekiq.rb` 中 `config.logger = File.open(...)` 直接赋值 File 对象，Sidekiq 7 需要 Logger 实例
- **修复**: 参考 voicebook 项目，改用 `Logger.new(path, "daily")`；同时修正 Redis URL 拼接（原代码错误地重复拼接了 `:6379/0`）

### 4. connection_pool 版本不兼容
- **现象**: Sidekiq 启动后 `wrong number of arguments (given 1, expected 0)`
- **原因**: `connection_pool 3.0.2` API 变更，Sidekiq 7.3.9 不兼容
- **修复**: `Gemfile` 锁定 `gem "connection_pool", "~> 2.4"`，使用 2.5.5

### 5. Sidekiq 文件上传失败
- **现象**: `FileUploadJob` 报错 `No such file or directory @ rb_sysopen`
- **原因**: web 和 worker 是独立容器，web 写入的 `/rails/tmp/uploads` 在 worker 容器中不存在
- **修复**: `deploy.staging.yml` 添加共享卷 `/zheli_read-staging/tmp:/rails/tmp`

### 6. tmp 目录权限
- **现象**: `Permission denied @ dir_s_mkdir - /rails/tmp/uploads`
- **原因**: 新挂载的 `/zheli_read-staging/tmp` 目录属主是 root，容器以 uid 1000 运行
- **修复**: `.kamal/hooks/post-deploy` 中添加 `chown -R 1000:1000 /zheli_read-staging/tmp`

### 7. kamal-proxy 服务名冲突
- **现象**: `Error: host settings conflict with another service`
- **原因**: 旧版部署创建的服务名 `zheli_read-staging-web` 与新版 `zheli_read-staging-web-staging` 冲突
- **修复**: 手动 `docker exec kamal-proxy kamal-proxy remove zheli_read-staging-web` 清理旧服务

## 测试服务器资源基准 (2026-05-11)
- 内存: 1.6Gi，已用 ~838Mi
- 硬盘: 40G，已用 17%（6.3G）
