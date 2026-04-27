# VoiceBook 部署文档

## 项目概述

VoiceBook 是一个儿童教育阅读平台后端 API 项目，基于 Ruby on Rails 8.0.5，使用 Grape 框架提供 RESTful API。

- **Ruby**: 3.3.0
- **Rails**: 8.0.5
- **数据库**: MySQL 8.0 (阿里云 RDS)
- **Web 服务器**: Puma
- **部署方式**: Docker + Kamal

---

## 一、本地开发环境搭建

### 1.1 前置条件

```bash
# Ruby 3.3.0 (通过 rvm 安装)
rvm install 3.3.0
rvm use 3.3.0

# MySQL 8.0
brew install mysql
brew services start mysql

# 为了让本地 PDF->EPUB 裁图结果尽量与 Ubuntu 一致，推荐安装 poppler
brew install poppler

# Docker (可选，用于容器化运行)
# 下载 Docker Desktop: https://www.docker.com/products/docker-desktop
```

### 1.2 项目初始化

```bash
# 克隆项目
cd /path/to/workspace
git clone <repo-url> voicebook
cd voicebook

# 安装依赖
bundle install

# 复制环境变量配置
cp .env.example .env
# 编辑 .env 文件，填入数据库等配置

# 创建数据库并执行迁移
bin/rails db:create
bin/rails db:migrate

# 加载种子数据
bin/rails db:seed
```

### 1.3 启动开发服务器

```bash
bin/rails server
# 访问 http://localhost:3000 查看 Hello World 页面
# 访问 http://localhost:3000/api 查看 API 状态
```

### 1.4 运行测试

```bash
# 运行所有测试
bundle exec rspec

# 运行指定测试
bundle exec rspec spec/models/user_spec.rb
bundle exec rspec spec/requests/api/v1/users_spec.rb

# 查看覆盖率报告
open coverage/index.html
```

---

## 二、Docker 构建与运行

### 2.1 使用 Docker 构建镜像

```bash
# 构建 Docker 镜像
docker build -t voicebook:latest .

# 查看构建结果
docker images | grep voicebook
```

说明：

- 生产镜像里需要 `poppler-utils`
- 项目在 Ubuntu / Debian 上使用 `pdftocairo` 完成 PDF 页面裁图、标题裁图和扫描版整页渲染

### 2.2 使用 Docker Compose 运行

```bash
# 设置必要的环境变量
export SECRET_KEY_BASE=$(openssl rand -hex 64)
export RAILS_MASTER_KEY=$(cat config/master.key)

# 启动所有服务（MySQL + Rails）
docker-compose up -d

# 查看日志
docker-compose logs -f web

# 停止服务
docker-compose down
```

### 2.3 单独运行 Docker 容器

```bash
# 如果使用外部数据库（如阿里云 RDS）
docker run -d \
  -p 3000:3000 \
  -e RAILS_ENV=production \
  -e DATABASE_HOST=rm-bp1eys5wpr344yf9v.mysql.rds.aliyuncs.com \
  -e DATABASE_PORT=3306 \
  -e DATABASE_USERNAME=voicebook \
  -e DATABASE_PASSWORD=your_password \
  -e DATABASE_NAME=voicebook_production \
  -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  --name voicebook \
  voicebook:latest
```

### 2.4 Docker 健康检查

```bash
# 检查容器健康状态
docker inspect --format='{{.State.Health.Status}}' voicebook

# 手动测试健康检查接口
curl http://localhost:3000/up
```

---

## 三、Kamal 部署到阿里云服务器

### 3.1 服务器信息

| 项目 | 值 |
|------|------|
| 服务器 IP | 114.215.208.190 |
| SSH 用户 | root |
| 数据库 | 阿里云 RDS MySQL |
| RDS 内网地址 | rm-bp1eys5wpr344yf9v.mysql.rds.aliyuncs.com |

### 3.2 服务器准备

```bash
# SSH 登录服务器
ssh -lroot 114.215.208.190

# 安装 Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# 创建应用目录
mkdir -p /opt/voicebook
```

### 3.3 配置 Kamal

编辑 `config/deploy.yml`，确保以下配置正确：

```yaml
service: voicebook
image: voicebook/voicebook

servers:
  web:
    hosts:
      - 114.215.208.190

registry:
  server: ghcr.io
  username:
    - KAMAL_REGISTRY_USERNAME
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    RAILS_ENV: production
    DATABASE_HOST: rm-bp1eys5wpr344yf9v.mysql.rds.aliyuncs.com
```

### 3.4 设置部署密钥

```bash
# 在本地创建 .env 文件（如不存在）
# 填入以下密钥信息：
KAMAL_REGISTRY_USERNAME=your_github_username
KAMAL_REGISTRY_PASSWORD=your_github_token
SECRET_KEY_BASE=$(openssl rand -hex 64)
RAILS_MASTER_KEY=$(cat config/master.key)
DATABASE_USERNAME=voicebook
DATABASE_PASSWORD=your_rds_password
```

### 3.5 执行部署

```bash
# 首次部署（安装 Kamal + 初始化服务器）
kamal setup

# 后续部署
kamal deploy

# 查看部署状态
kamal details

# 查看应用日志
kamal app logs

# 回滚到上一个版本
kamal rollback
```

---

## 四、数据库管理

### 4.1 阿里云 RDS 配置

```bash
# 登录 RDS（通过 ECS 内网）
mysql -h rm-bp1eys5wpr344yf9v.mysql.rds.aliyuncs.com -u voicebook -p

# 创建生产数据库
CREATE DATABASE voicebook_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# 创建用户并授权
CREATE USER 'voicebook'@'%' IDENTIFIED BY 'your_secure_password';
GRANT ALL PRIVILEGES ON voicebook_production.* TO 'voicebook'@'%';
FLUSH PRIVILEGES;
```

### 4.2 数据库迁移

```bash
# 本地执行
bin/rails db:migrate

# 生产环境（通过 Kamal）
kamal app exec 'bin/rails db:migrate'

# 加载种子数据
kamal app exec 'bin/rails db:seed'
```

### 4.3 数据库备份

```bash
# 通过阿里云 RDS 控制台配置自动备份
# 或手动备份：
mysqldump -h rm-bp1eys5wpr344yf9v.mysql.rds.aliyuncs.com \
  -u voicebook -p voicebook_production > backup_$(date +%Y%m%d).sql
```

---

## 五、API 接口说明

### 5.1 基础地址

- 本地开发: `http://localhost:3000/api`
- 生产环境: `http://114.215.208.190/api`

### 5.2 接口列表

| 模块 | 接口 | 方法 | 说明 | 认证 |
|------|------|------|------|------|
| **首页** | /api/home | GET | 首页数据 | 否 |
| | /api/home/banners | GET | 轮播图 | 否 |
| | /api/home/recommendations | GET | 推荐列表 | 否 |
| | /api/home/reading_levels | GET | 分级阅读 | 否 |
| | /api/home/collections | GET | 合集列表 | 否 |
| **用户** | /api/users/send_code | POST | 发送验证码 | 否 |
| | /api/users/login_by_code | POST | 验证码登录 | 否 |
| | /api/users/login_by_password | POST | 密码登录 | 否 |
| | /api/users/profile | GET | 获取资料 | 是 |
| | /api/users/profile | PUT | 更新资料 | 是 |
| | /api/users/reading_stats | GET | 阅读统计 | 是 |
| **图书** | /api/books | GET | 图书列表 | 否 |
| | /api/books/:id | GET | 图书详情 | 否 |
| | /api/books/:id/chapters | GET | 章节列表 | 否 |
| | /api/books/:id/chapters/:id | GET | 章节内容 | 是 |
| **有声** | /api/audio/albums | GET | 专辑列表 | 否 |
| | /api/audio/albums/:id | GET | 专辑详情 | 否 |
| | /api/audio/albums/:id/episodes | GET | 节目列表 | 否 |
| | /api/audio/episodes/:id/play | GET | 播放节目 | 是 |
| **分类** | /api/categories | GET | 分类列表 | 否 |
| | /api/categories/:id | GET | 分类详情 | 否 |
| | /api/categories/:id/books | GET | 分类图书 | 否 |
| | /api/grades | GET | 年级列表 | 否 |
| **书架** | /api/bookshelves | GET | 书架列表 | 是 |
| | /api/bookshelves | POST | 添加到书架 | 是 |
| | /api/bookshelves/:id | DELETE | 移除书架 | 是 |
| | /api/bookshelves/:id/progress | PUT | 更新进度 | 是 |
| | /api/bookmarks | GET/POST/DELETE | 书签管理 | 是 |
| **搜索** | /api/search | GET | 搜索图书 | 否 |
| | /api/search/hot | GET | 热门搜索 | 否 |
| **会员** | /api/memberships/plans | GET | 套餐列表 | 否 |
| | /api/memberships/purchase | POST | 购买会员 | 是 |
| | /api/memberships/my | GET | 我的会员 | 是 |
| **排行榜** | /api/rankings | GET | 排行榜列表 | 否 |
| | /api/rankings/:id | GET | 排行榜详情 | 否 |
| **家长** | /api/parental/setup | POST | 设置密码 | 是 |
| | /api/parental/verify | POST | 验证密码 | 是 |
| | /api/parental/settings | GET | 管控设置 | 是 |
| | /api/parental/blacklist | GET/POST/DELETE | 黑名单 | 是 |

### 5.3 认证方式

API 使用签名认证（access_key_id + sign 签名）。在请求中携带：

```
X-Access-Key-Id: your_access_key_id
X-Sign: your_signature
```

签名生成方式：对请求参数按键排序后拼接 secret 进行 SHA1 哈希。

### 5.4 响应格式

```json
{
  "code": 0,
  "message": "success",
  "data": { ... }
}
```

错误码说明：
| 错误码 | 说明 |
|--------|------|
| 0 | 成功 |
| 1001 | 认证失败 |
| 1002 | 参数验证失败 |
| 1003 | 记录不存在 |
| 1004 | 权限不足 |
| 1005 | 服务器内部错误 |

---

## 六、监控与维护

### 6.1 日志查看

```bash
# Kamal 查看日志
kamal app logs -f

# Docker 直接查看
docker logs -f voicebook
```

### 6.2 健康检查

```bash
# 应用健康检查
curl http://114.215.208.190/up

# API 健康检查
curl http://114.215.208.190/api/up
```

### 6.3 重启应用

```bash
# 通过 Kamal
kamal app restart

# 通过 Docker
docker restart voicebook
```

---

## 七、常见问题

### Q1: Docker 构建失败，提示 gem 安装错误
确保 Dockerfile 中安装了 `default-libmysqlclient-dev` 依赖。

### Q2: 连接数据库失败
检查 RDS 安全组规则，确保 ECS 服务器的内网 IP 在白名单中。

### Q3: Puma 启动失败
检查 `config/puma.rb` 中的端口配置和 `config/master.key` 是否存在。

### Q4: 如何生成 master.key
```bash
EDITOR=vi bin/rails credentials:edit
```
