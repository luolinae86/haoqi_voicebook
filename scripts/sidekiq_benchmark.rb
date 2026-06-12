# frozen_string_literal: true

# Sidekiq 并发基准测试脚本
# 用法: bundle exec rails runner scripts/sidekiq_benchmark.rb

JOB_COUNT = 100
REDIS_KEY_DONE = 'bench:done'

# 1. 入队任务
Sidekiq.redis { |r| r.del(REDIS_KEY_DONE) }

puts "入队 #{JOB_COUNT} 个 BenchmarkWorker 任务..."
JOB_COUNT.times { |i| BenchmarkWorker.perform_async(i) }

# 2. 等待完成，记录时间
puts "等待处理..."
timeout = 120
start_time = Time.now
last_count = 0
stall_count = 0

loop do
  done = Sidekiq.redis { |r| r.get(REDIS_KEY_DONE).to_i }
  elapsed = Time.now - start_time

  if done >= JOB_COUNT
    total_time = elapsed
    puts ""
    puts "  总任务: #{JOB_COUNT}"
    puts "  总耗时: #{total_time.round(2)}s"
    puts "  吞吐量: #{(JOB_COUNT / total_time).round(1)} jobs/s"
    break
  end

  if elapsed > timeout
    puts ""
    puts "  超时（#{timeout}s），已完成 #{done}/#{JOB_COUNT}"
    puts "  吞吐量: #{(done / elapsed).round(1)} jobs/s"
    break
  end

  if done == last_count
    stall_count += 1
    if stall_count > 30
      puts ""
      puts "  30s 无进展，已完成 #{done}/#{JOB_COUNT}"
      break
    end
  else
    stall_count = 0
  end
  last_count = done

  print "\r  进度: #{done}/#{JOB_COUNT} (#{elapsed.round(1)}s)   "
  sleep 1
end

done_final = Sidekiq.redis { |r| r.get(REDIS_KEY_DONE).to_i }
puts "  最终完成数: #{done_final}"
Sidekiq.redis { |r| r.del(REDIS_KEY_DONE) }
