---
name: 避免修改 Dockerfile
description: 除非必须，否则不要主动修改 Dockerfile，避免触发 Kamal 重新构建导致部署缓慢
type: feedback
---

**规则：** 避免修改 Dockerfile

**Why:** Dockerfile 的每次修改都会导致 Kamal 触发完整镜像重建（bundle install、bootsnap 预编译等），耗时几分钟，部署非常慢。

**How to apply:** 除非是部署流程本身的问题（如镜像源失效、依赖变更），否则不要碰 Dockerfile。优先通过配置变更或代码修改来解决问题。