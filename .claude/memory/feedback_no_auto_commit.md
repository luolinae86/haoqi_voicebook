---
name: 严禁未经确认自动提交代码
description: 在用户明确要求提交代码之前，绝不要主动执行 git commit 或 git push。只展示 diff 和变更内容，等用户说"提交"再执行。
type: feedback
---

**Rule:** 绝不在用户明确说"提交代码"或"commit"之前执行 git commit 或 git push。

**Why:** 用户需要先 review 变更，确认无误后再提交。自动提交可能导致未审查的代码进入仓库。

**How to apply:** 完成代码修改后，只展示 diff 和变更内容给用户看。用户明确说"提交"、"commit"、"push"等命令时，才可以执行。
