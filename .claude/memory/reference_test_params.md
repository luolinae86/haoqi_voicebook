---
name: 默认测试参数
description: 测试环境默认使用的 UUID 和 auth_code 值
type: reference
---

**UUID：** `2dd92a600912465dada3f955d6cc3bdc`
**auth_code：** `ACAPTCHA10403009`
**测试服务器：** `https://testwm.ylb.io`

**Why：** 用户指定的固定测试参数，每次部署后都需要用这些参数验证扫码枪接口。

**How to apply：** 写测试用例后部署测试环境，用 `curl https://testwm.ylb.io/api/v4/scan_bar/bind_result?uuid=2dd92a600912465dada3f955d6cc3bdc` 及对应 auth_code 验证功能。