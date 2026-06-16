---
name: 零停机部署流程
description: voicebook 必须使用 bin/safe_deploy.sh 确保安全部署，绝不允许服务中断
type: feedback
---

**规则：** 部署必须使用 `bin/safe_deploy.sh` 脚本，禁止直接 `kamal deploy`。部署前必须先 `git pull` 拉取最新代码，部署成功后必须 `git push` 推送本地提交。

**Why：** 多次出现 kamal deploy 被中断导致服务完全不可用的情况（SSH/HTTP 全部超时），影响线上服务。本地有 7 个未 push 的提交会导致远端落后于本地，影响协作。

**How to apply：**

**安全部署流程（bin/safe_deploy.sh）：**
1. 部署前：`git pull` 确保本地代码最新，检查健康（`curl /up` 必须 200），记录当前版本，检查部署锁
2. 部署中：执行 `kamal deploy`（kamal-proxy 自动零停机：新容器健康后再切流量）
3. 部署后：验证健康检查通过（最多重试 60 秒），执行 db:migrate，展示资源状态
4. 部署成功后：`git push` 推送本地提交到远端
5. 失败时：自动回滚到上一版本

**deploy.yml 关键配置（不可随意改小）：**
- `deploy_timeout: 90` — 新容器健康检查超时
- `drain_timeout: 30` — 旧容器优雅下线等待
- `retain_containers: 3` — 保留 3 个旧版本用于快速回滚
- `proxy.healthcheck.timeout: 10` — 健康检查单次超时

**如果部署中断：**
1. 释放部署锁：`kamal lock release`
2. 检查状态：`kamal app details`
3. 回滚：`kamal app rollback`
4. 验证：`curl https://voicebook.haoqiniu.com/up`
