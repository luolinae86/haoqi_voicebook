# 国内环境下使用 Kamal 部署 Docker 完整指南

## 一、背景

Kamal 是 Basecamp 开发的 Ruby on Rails 零停机部署工具。国内部署面临三大网络挑战：
1. Docker Hub 拉取基础镜像慢或不稳定
2. Debian/Ubuntu apt 源连接失败
3. RubyGems 官方源不可达

## 二、环境准备

### 2.1 服务器要求

- 阿里云 ECS（本例：`114.215.208.190`）
- 已安装 Docker
- 安全组开放 80、443 端口
- SSH 22 端口可访问

### 2.2 本地要求

- Ruby 3.3.0+
- Kamal 2.x（`gem install kamal`）
- 本地 Docker（用于构建镜像）

### 2.3 Docker Registry

使用自建 Docker Registry（本例：`reg.ylb.im`），替代 Docker Hub 作为镜像中转站。

## 三、配置步骤

### 3.1 Kamal 配置文件 `config/deploy.yml`

```yaml
service: voicebook
image: voicebook/voicebook

servers:
  web:
    hosts:
      - 114.215.208.190

registry:
  server: reg.ylb.im
  username:
    - KAMAL_REGISTRY_USERNAME
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    RAILS_ENV: production
    WEB_CONCURRENCY: 2
    RAILS_MAX_THREADS: 5
  secret:
    - SECRET_KEY_BASE
    - DATABASE_PRD_USERNAME
    - DATABASE_PRD_PASSWORD
    - DATABASE_PRD_HOST
    - DATABASE_PRD_PORT
    - DATABASE_PRD_DATABASE
    - JWT_SECRET

ssh:
  user: root
  port: 22
  keys:
    - ~/.ssh/id_rsa

proxy:
  ssl: true
  host: api.zheliyuedu.cn
  healthcheck:
    path: /up
    interval: 5
    timeout: 5

builder:
  arch: amd64
```

**关键点：**
- `image` 不包含 registry 前缀，Kamal 会自动拼接
- `proxy` 不需要 `app_port` 时默认使用 80（Puma 默认端口需设为 80）
- 移除 `RAILS_MASTER_KEY`（项目无 Rails credentials 时不需要）
- 移除 `servers.web.options.network: "kamal"`（与 proxy 冲突）
- `registry.server` 不要加 `https://` 协议前缀

### 3.2 Kamal Secrets 文件 `.kamal/secrets`

```yaml
TZ=Asia/Shanghai

KAMAL_REGISTRY_USERNAME=你的用户名
KAMAL_REGISTRY_PASSWORD=你的密码

SECRET_KEY_BASE=openssl rand -hex 64 生成的64字节hex字符串
DATABASE_PRD_HOST=rm-xxx.mysql.rds.aliyuncs.com
DATABASE_PRD_PORT=3306
DATABASE_PRD_USERNAME=voice_book
DATABASE_PRD_PASSWORD=你的密码
DATABASE_PRD_DATABASE=voice_book
JWT_SECRET=你的jwt密钥
```

**关键点：**
- 此文件已在 `.gitignore` 中，**绝不要提交到版本控制**
- `SECRET_KEY_BASE` 必须是非空字符串，用于 Rails 加密和消息签名
- 没有 Rails credentials 时，不需要 `RAILS_MASTER_KEY`

### 3.3 Dockerfile（国内优化版）

```dockerfile
# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.3.0
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# 1. 替换 Debian 源为阿里云镜像，解决国内网络问题
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources

# 2. 安装基础包
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl default-mysql-client libjemalloc2 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# 3. Build 阶段
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential default-libmysqlclient-dev git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 安装匹配的 Bundler 版本（使用阿里云镜像源）
RUN gem install bundler -v 4.0.10 --source https://mirrors.aliyun.com/rubygems/ --no-document

COPY Gemfile Gemfile.lock ./

# 使用阿里云 RubyGems 镜像源
RUN bundle config set frozen false && \
    bundle config set mirror.https://rubygems.org https://mirrors.aliyun.com/rubygems/ && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/

# 4. 最终阶段
FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:80/up || exit 1

EXPOSE 80

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### 3.4 Puma 配置 `config/puma.rb`

```ruby
# 默认端口改为 80，与 kamal-proxy 默认 app_port 保持一致
port ENV.fetch("PORT", 80)
```

### 3.5 `.gitignore`

确保敏感文件不被提交：

```
/.kamal/secrets
/.env*
/config/*.key
```

## 四、部署流程

完整的部署命令只需一条：

```bash
kamal deploy
```

**Kamal 自动执行的步骤：**

1. **本地构建镜像** - 在本地 Docker 环境中执行多阶段构建
2. **推送到 Registry** - 将镜像推送到 `reg.ylb.im/voicebook/voicebook:版本哈希`
3. **远端拉取镜像** - 在目标服务器从 Registry 拉取镜像
4. **启动容器** - 使用配置的环境变量启动应用容器
5. **kamal-proxy 部署** - 将流量路由到新容器，健康检查通过后再切换
6. **清理旧容器** - 自动清理旧的容器和镜像

## 五、常见问题与解决方案

### 5.1 `deb.debian.org` 连接失败

**症状：** `apt-get install` 报错 `Connection failed [IP: 151.101.130.132 80]`

**解决：** 在 Dockerfile `base` 阶段添加 sed 命令替换为阿里云镜像源

### 5.2 RubyGems 安装/下载慢

**症状：** `gem install bundler` 或 `bundle install` 超时

**解决：** 配置 RubyGems 镜像：`bundle config set mirror.https://rubygems.org https://mirrors.aliyun.com/rubygems/`

### 5.3 `secret_key_base` 为空导致启动失败

**症状：** `ArgumentError: secret_key_base for production environment must be a type of String`

**解决：** 在 `.kamal/secrets` 中设置 `SECRET_KEY_BASE=openssl rand -hex 64`

### 5.4 `RAILS_MASTER_KEY` 导致解密失败

**症状：** `ArgumentError: key must be 16 bytes`

**解决：** 项目没有 `config/credentials/` 文件时，从 `deploy.yml` secret 列表中移除 `RAILS_MASTER_KEY`

### 5.5 容器启动成功但健康检查失败

**症状：** kamal-proxy 报 `connection refused` 或 `server misbehaving`

**原因：** Puma 默认监听 3000 端口，但 kamal-proxy 默认连接 80 端口

**解决：** 将 Puma 默认端口改为 80，或在 `deploy.yml` 中设置 `proxy.app_port: 3000`

### 5.6 Zeitwerk 文件命名不匹配

**症状：** `uninitialized constant Api::Errors::Common (NameError)`

**原因：** 文件名 `common.rb` 与类名 `CommonError` 不匹配

**解决：** 文件必须与类名对应，`common_error.rb` 对应 `CommonError`

### 5.7 `network "kamal" is specified multiple times`

**原因：** 同时配置了 `proxy`（自动使用 kamal 网络）和 `servers.web.options.network: "kamal"`

**解决：** 移除 `options.network` 配置

### 5.8 `registry.server` 带协议前缀

**症状：** `ArgumentError: bad argument (expected URI object or URI string)`

**解决：** `registry.server` 不要加 `https://`，只写域名如 `reg.ylb.im`

## 六、部署收益

### 6.1 零停机部署

Kamal 通过 kamal-proxy 实现无缝切换：
- 新容器启动并健康检查通过后，才将流量切换过去
- 旧容器在流量切换后优雅关闭
- 用户完全感知不到部署过程

### 6.2 一键部署

一条 `kamal deploy` 命令完成：构建 → 推送 → 拉取 → 启动 → 健康检查 → 切换

### 6.3 版本回滚

```bash
kamal rollback <version>
```

可以立即回滚到任意历史版本

### 6.4 镜像版本管理

每个部署版本对应 git commit hash，清晰可追溯，不会混淆

### 6.5 环境变量隔离

敏感配置通过 `.kamal/secrets` 管理，不进入代码仓库，部署时自动注入

### 6.6 自动清理

部署完成后自动清理旧容器和镜像，避免服务器磁盘被占满

### 6.7 多环境支持

通过 `--destination` 参数可支持 staging、production 等多环境部署

### 6.8 资源利用

- Docker 多阶段构建：编译阶段和运行阶段分离，最终镜像只包含运行时必要文件
- jemalloc 内存优化：降低 Ruby 内存占用
- Bootsnap 预编译：加快 Rails 启动速度

## 七、网络优化总结

| 场景 | 默认源 | 国内替代方案 |
|---|---|---|
| Debian apt | deb.debian.org | mirrors.aliyun.com |
| RubyGems | rubygems.org | mirrors.aliyun.com/rubygems |
| Docker Hub | registry-1.docker.io | 自建 Registry reg.ylb.im |
| Docker 基础镜像 | Docker Hub | 配置 Docker 加速器或使用远端构建 |

## 八、注意事项

1. **SSL 证书**：设置 `proxy.ssl: true` 时，kamal-proxy 会自动通过 Let's Encrypt 申请证书，需要域名 DNS 指向服务器 IP
2. **端口一致性**：确保 Dockerfile EXPOSE、Puma port、kamal-proxy app_port 三者一致
3. **安全组**：阿里云安全组需开放 80、443 端口
4. **数据库**：确保应用服务器能访问阿里云 RDS（RDS 白名单需包含应用服务器内网 IP）
5. **内存**：Rails 8 + Puma workers 建议至少 2GB 内存
