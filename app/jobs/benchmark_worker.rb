# frozen_string_literal: true

# Sidekiq 并发基准测试 Job
# 模拟典型业务：DB 查询 + 轻量计算
class BenchmarkWorker
  include Sidekiq::Job

  sidekiq_options queue: 'default', retry: 0

  def perform(job_id)
    # 模拟真实业务：DB 查询 + 外部 API 调用（I/O 等待）
    AppUser.limit(10).to_a
    sleep(0.05) # 模拟 50ms I/O 等待（HTTP/API/Redis 调用）
    sum = 0
    5_000.times { |i| sum += i }
    # 写入 Redis 标记完成
    Sidekiq.redis { |r| r.incr("bench:done") }
  end
end
