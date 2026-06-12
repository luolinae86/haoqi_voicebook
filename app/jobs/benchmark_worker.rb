# frozen_string_literal: true

# Sidekiq 并发基准测试 Job
# 模拟典型业务：DB 查询 + 轻量计算
class BenchmarkWorker
  include Sidekiq::Job

  sidekiq_options queue: 'default', retry: 0

  def perform(job_id)
    # 模拟 DB 查询（类似真实 API 业务）
    AppUser.limit(10).to_a
    # 模拟轻量计算
    sum = 0
    10_000.times { |i| sum += i }
    # 写入 Redis 标记完成
    Sidekiq.redis { |r| r.incr("bench:done") }
  end
end
