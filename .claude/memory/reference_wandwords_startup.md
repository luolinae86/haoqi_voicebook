---
name: wandwords 本地启动流程
description: wandwords 项目本地启动步骤（基于本地 MySQL + Redis）
type: reference
---

**前提**：
- 本地已安装 MySQL 8.x（Homebrew）和 Redis
- Ruby 3.3.0（rvm）

**启动步骤**：
1. `cd /Users/luolin/workspace/project/cloudhorn/wandwords`
2. `rvm use 3.3.0`
3. `bundle install`（依赖安装到 `./vendor/bundle`）
4. `bundle exec rails db:prepare`（创建/迁移数据库）
5. `bundle exec rails server -b 0.0.0.0 -p 3000`（启动 Puma）

**环境**：
- `.env` 配置了 `DATABASE_HOST=127.0.0.1`、`DATABASE_PORT=3306`、`DATABASE_NAME=wandwords_development`、`REDIS_URL=redis://127.0.0.1:6379/1`
- 本地 MySQL 在 3306 端口，Redis 在 6379 端口
- 服务地址 http://localhost:3000
