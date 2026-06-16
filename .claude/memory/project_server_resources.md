---
name: 测试服务器资源配置
description: 测试服务器 8.136.142.85 的硬件资源基准数据（2026-05-11 更新）
type: project
---

测试服务器 (8.136.142.85) 资源基准 — 2026-05-11 部署后记录:
- 总内存: 1.6Gi
- 已用内存: 838Mi（含 web + worker + kamal-proxy 三个容器）
- 可用内存: 774Mi
- Swap: 无
- 硬盘: 40G 总容量，已用 6.3G（17%），剩余 31G

运行容器:
- zheli_read-staging-web-staging
- zheli_read-staging-worker-staging
- kamal-proxy

注意：voicebook-staging 容器之前已被停掉。
