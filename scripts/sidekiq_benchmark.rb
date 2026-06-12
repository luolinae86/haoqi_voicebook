# frozen_string_literal: true

# Sidekiq 并发基准测试脚本
# 用法: bundle exec rails runner scripts/sidekiq_benchmark.rb

require 'redis'

JOB_COUNT = 100
REDIS_KEY_DONE = 'bench:done'
REDIS_KEY_START = 'bench:start'

# 1. 入队任务
redis = Redis.new(url: ENV['REDIS_URL'], password: ENV['REDIS_PASSWORD'])
redis.del(REDIS_KEY_DONE)
redis.del(REDIS_KEY_START)

puts "入队 #{JOB_COUNT} 个 BenchmarkWorker 任务..."
JOB_COUNT.times { |i| BenchmarkWorker.perform_async(i) }

# 2. 等待完成，记录时间
redis.set(REDIS_KEY_START, Time.now.to_f)
puts "等待处理..."

timeout = 120
start_time = Time.now
last_count = 0
stall_count = 0

loop do
  done = redis.get(REDIS_KEY_DONE).to_i
  elapsed = Time.now - start_time

  if done >= JOB_COUNT
    total_time = elapsed
    puts "\n✅ 完成！"
    puts "  总任务: #{JOB_COUNT}"
    puts "  总耗时: #{total_time.round(2)}s"
    puts "  吞吐量: #{(JOB_COUNT / total_time).round(1)} jobs/s"
    break
  end

  if elapsed > timeout
    puts "\n❌ 超时（#{timeout}s），已完成 #{done}/#{JOB_COUNT}"
    puts "  吞吐量: #{(done / elapsed).round(1)} jobs/s"
    break
  end

  # 检测卡住
  if done == last_count
    stall_count += 1
    if stall_count > 30
      puts "\n❌ 30s 无进展，可能卡住。已完成 #{done}/#{JOB_COUNT}"
      break
    end
  else
    stall_count = 0
  end
  last_count = done

  print "\r  进度: #{done}/#{JOB_COUNT} (#{elapsed.round(1)}s)   "
  sleep 1
end

puts "\n  最终完成数: #{redis.get(REDIS_KEY_DONE).to_i}"
redis.del(REDIS_KEY_DONE)
redis.del(REDIS_KEY_START)
