---
name: 部署前必须先提交代码
description: 每次部署前必须先 git commit 当前代码改动，确保容器使用的镜像与已提交的代码一致
type: feedback
---

部署前必须先提交代码（git commit）。

**Why:** 之前出现过代码已修改但未 commit，kamal deploy 使用的是本地 git HEAD，导致部署的代码与实际文件不一致。

**How to apply:** 任何修改代码后，在执行 `kamal deploy` 之前，必须先 `git add` + `git commit`。
