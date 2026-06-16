---
name: 部署标准流程
description: voicebook 项目部署的完整五步流程，顺序不可更改
type: feedback
---

执行部署时必须严格按以下顺序执行，缺一不可：

1. **git commit** — 提交当前代码改动（确保部署镜像与已提交代码一致）
2. **git push** — 推送到远程仓库（确保远程同步）
3. **kamal deploy** — 构建并部署新容器
4. **kamal app exec "bundle exec rails db:migrate"** — 迁移数据库
5. **展示服务器资源状态** — 执行 `free -h | grep Mem`、`df -h /`、`uptime`，展示内存/CPU/硬盘/负载情况

**Why:** 之前多次遗漏步骤（没提交就部署、没push、没展示资源状态），导致不一致和排查困难。

**How to apply:** 只要用户提到"部署"/"deploy"/"发布"等关键词，必须完整执行以上五步，不可跳过或调换顺序。部署后资源检查不可省略，必须展示给用户。
