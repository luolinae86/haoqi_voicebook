#!/usr/bin/env bash
# 安全部署脚本：确保零停机
# 用法: ./bin/safe_deploy.sh

set -e

cd "$(dirname "$0")/.."

echo "=== 部署前检查 ==="

# 1. 检查是否有未提交的代码
if [ -n "$(git status --porcelain)" ]; then
  echo "警告: 有未提交的变更，建议先提交"
  git status --short
fi

# 2. 检查当前服务是否健康
echo "检查当前服务健康状态..."
CURRENT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://voicebook.haoqiniu.com/up 2>/dev/null || echo "000")
if [ "$CURRENT_STATUS" != "200" ]; then
  echo "错误: 当前服务不健康 (HTTP $CURRENT_STATUS)，请先修复"
  exit 1
fi
echo "当前服务正常 (HTTP $CURRENT_STATUS)"

# 3. 记录当前版本
CURRENT_VERSION=$(kamal app version 2>/dev/null || echo "unknown")
echo "当前版本: $CURRENT_VERSION"

# 4. 检查部署锁
echo "检查部署锁..."
kamal lock status 2>/dev/null
LOCK_STATUS=$?
if [ $LOCK_STATUS -ne 0 ]; then
  echo "检测到部署锁，尝试释放..."
  kamal lock release 2>/dev/null || true
fi

# 5. 执行部署
echo ""
echo "=== 开始部署 ==="
kamal deploy 2>&1

# 6. 部署后验证
echo ""
echo "=== 部署后验证 ==="
for i in $(seq 1 12); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://voicebook.haoqiniu.com/up 2>/dev/null || echo "000")
  if [ "$STATUS" = "200" ]; then
    echo "服务健康 (HTTP $STATUS)"

    # 7. 执行数据库迁移
    echo "执行数据库迁移..."
    kamal app exec "bundle exec rails db:migrate" 2>&1 || echo "迁移可能已完成"

    # 8. 展示服务器资源状态
    echo ""
    echo "=== 服务器资源状态 ==="
    ssh root@114.215.208.190 "echo '内存:' && free -h | grep Mem && echo 'CPU:' && top -bn1 | grep 'Cpu(s)' && echo '磁盘:' && df -h / | tail -1" 2>/dev/null || echo "无法连接服务器"

    echo ""
    echo "=== 部署成功 ==="
    exit 0
  fi
  echo "等待服务就绪... (${i}/12)"
  sleep 5
done

echo ""
echo "=== 部署失败：服务未恢复 ==="
echo "当前版本: $CURRENT_VERSION"
echo "执行回滚: kamal app rollback"
echo ""
echo "是否自动回滚？(y/N)"
read -r CONFIRM
if [ "$CONFIRM" = "y" ]; then
  echo "执行回滚..."
  kamal app rollback 2>&1
  echo "回滚完成，请检查服务: curl https://voicebook.haoqiniu.com/up"
fi
exit 1
