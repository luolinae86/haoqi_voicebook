---
name: 自动 commit 后再 push
description: 用户要求每次 push 代码前自动先 commit，不再单独确认
type: feedback
---

**Rule:** push 之前必须先自动 commit 变更，不再额外询问。
**Why:** 用户觉得每次都要手动确认 commit 太繁琐。
**How to apply:** 当用户说 push 或部署代码时，先 git add + git commit（参考最近的 commit 风格写 message），再 git push。
