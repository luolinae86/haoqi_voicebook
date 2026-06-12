# frozen_string_literal: true

# Sidekiq 并发模拟基准测试
# 不依赖 Sidekiq 进程，直接用线程池模拟不同并发级别
# 用法: bundle exec rails runner scripts/sidekiq_thread_benchmark.rb

require 'benchmark'

JOB_COUNT = 200
CONCURRENCY_LEVELS = [2, 4, 6, 8, 12, 16, 24, 32]

# 模拟一个典型的 Sidekiq Job（DB 查询 + I/O 等待 + Redis 写入）
def simulate_job(job_id)
  # 模拟 DB 查询
  AppUser.limit(10).to_a
  # 模拟 I/O 等待（HTTP/API 调用）
  sleep(0.05)
  # 模拟轻量计算
  sum = 0
  5_000.times { |i| sum += i }
  sum
end

puts "=" * 60
puts "  Sidekiq 并发基准测试"
puts "  任务数: #{JOB_COUNT} | 单任务模拟: 50ms I/O"
puts "=" * 60
puts ""
printf "%-12s | %-10s | %-10s | %-10s | %-8s\n", "并发数", "总耗时", "吞吐量", "P95", "P99"
puts "-" * 60

CONCURRENCY_LEVELS.each do |concurrency|
  # 用 Queue 分发任务
  queue = Queue.new
  JOB_COUNT.times { |i| queue << i }

  timings = []
  mutex = Mutex.new
  start_all = Time.now

  # 启动 concurrency 个线程
  threads = concurrency.times.map do
    Thread.new do
      while true
        begin
          job_id = queue.pop(true)
        rescue ThreadError
          break
        end
        job_start = Time.now
        simulate_job(job_id)
        elapsed = Time.now - job_start
        mutex.synchronize { timings << elapsed }
      end
    end
  end

  threads.each(&:join)
  total_time = Time.now - start_all

  timings.sort!
  p95 = timings[(timings.length * 0.95).to_i]
  p99 = timings[(timings.length * 0.99).to_i]
  throughput = JOB_COUNT / total_time

  printf "%-12s | %-10s | %-10s | %-10s | %-8s\n",
    concurrency,
    "#{total_time.round(2)}s",
    "#{throughput.round(1)} j/s",
    "#{(p95 * 1000).round(0)}ms",
    "#{(p99 * 1000).round(0)}ms"
end

puts ""
puts "说明: P95/P99 为单个任务的完成时间（非整体）"
puts "      吞吐量 = 总任务数 / 总耗时"
