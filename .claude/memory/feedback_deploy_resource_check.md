---
name: 部署后展示并分析服务器资源状态
description: 每次部署完成后必须通过 SSH 查询服务器内存、CPU、硬盘等资源使用率，并向用户汇报资源状态，同时分析判断服务器是否健康
type: feedback
---

每次 `kamal deploy` 完成后，必须做以下事情：

1. 通过 SSH 查询服务器资源状态（`free -m`、`top -bn1 | head`、`df -h /`）
2. 向用户汇报当前资源使用情况
3. 分析判断服务器是否健康：
   - **内存**：可用内存 < 15% 为异常（即使用率 > 85%）
   - **硬盘**：根分区使用率 > 80% 为异常
   - **CPU**：idle < 10% 为异常
   - 如果指标异常，需向用户说明可能的原因和建议（如 docker 清理、Sidekiq 队列积压等）
4. 执行 docker container prune 和 docker image prune 清理无用容器镜像