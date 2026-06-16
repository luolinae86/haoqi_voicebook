---
name: 部署前必须先 push 代码到远程仓库
description: 每次执行 kamal deploy 之前必须先 git push，确保远程仓库有最新代码
type: feedback
---

**Rule:** 部署前必须先 `git push` 到远程仓库，再执行 `kamal deploy`。

**Why:** 部署的镜像是基于提交的代码构建的，如果只 commit 不 push，远程仓库与部署版本不一致，会导致代码追踪和回滚困难。

**How to apply:** 在 `kamal deploy` 之前，确保执行 `git push`。顺序：commit → push → deploy。
