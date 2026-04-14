# 04.2 - Redis

> **适用**：设计 Redis key、决定数据类型、用 TTL、做缓存 / 分布式锁 / 限流 / 排行榜。
>
> Redis 是**辅助存储**，不是主存储。重要数据必须持久化到 MySQL，Redis 内容随时可丢失。

## 何时用 Redis

| 场景 | 数据类型 |
|------|---------|
| 缓存（cache aside） | string / hash |
| 分布式锁 | string + SET NX EX |
| 计数器、限流 | string (INCR) |
| 排行榜 | sorted set (zset) |
| 实时去重、布隆 | set / HyperLogLog |
| 会话 / token 状态 | string / hash + TTL |
| 消息队列（轻量） | list / stream |
| 发布订阅 | pub/sub / stream |

## Key 命名规范

```
<service>:<entity>:<id>:<attr>
```

| 部分 | 说明 | 示例 |
|------|------|------|
| service | 服务名（namespace） | `liaison` |
| entity | 业务实体 | `user` / `edge` / `session` |
| id | 实体 ID | `12345` |
| attr | 子属性（可选） | `profile` / `quota` |

```
# ✅ 正确
liaison:user:12345:profile
liaison:edge:67890:status
liaison:session:abc123def456
liaison:lock:order:create:12345
liaison:ratelimit:login:1.2.3.4

# ❌ 错误
user_12345                  # 缺 namespace，多服务共用 Redis 会冲突
liaison.user.12345          # 用 . 不用 :（Redis 约定用 :）
USER:12345                  # 大小写混用
liaison:user:12345:name:email:phone:address  # 嵌套过深
```

**规则：**
- 小写 + `:` 分隔
- namespace 必填，避免多服务冲突
- key 长度建议 < 64 字符
- 禁止把不可控数据（用户输入）直接拼 key

## TTL 是必须的

```go
// ✅ 所有 key 必须设 TTL
redis.Set(ctx, key, val, 24*time.Hour)
redis.SetNX(ctx, lockKey, owner, 30*time.Second)

// ❌ 禁止：无 TTL 的 key 会变成内存泄漏
redis.Set(ctx, key, val, 0)
```

**例外**：长期数据（如配置、字典）允许无 TTL，但必须代码注释说明，且建议放独立 db 或 namespace 便于审计。

### TTL 选择

| 用途 | 推荐 TTL |
|------|---------|
| 接口缓存 | 1-10 min |
| 用户会话 | 30 min - 24 h（带刷新） |
| 验证码 | 5 min |
| 分布式锁 | 业务最长耗时 × 2 |
| 限流计数 | 滑动窗口大小 |
| 排行榜 | 业务周期（日榜 1 day、周榜 7 day） |

## 数据类型选择

### String

最常用，存序列化 JSON / 计数器 / token。

```go
// 业务对象用 JSON
data, _ := json.Marshal(user)
redis.Set(ctx, "liaison:user:123", data, time.Hour)

// 计数器用 INCR
redis.Incr(ctx, "liaison:counter:order:today")
```

### Hash

存对象，**单字段更新**比 String JSON 高效。

```go
redis.HSet(ctx, "liaison:user:123", map[string]interface{}{
    "name":    "alice",
    "email":   "a@b.com",
    "balance": 100,
})
redis.HIncrBy(ctx, "liaison:user:123", "balance", -10)
```

**何时选 Hash 而非 String**：字段独立更新频繁、字段数 < 100。

### Sorted Set（zset）

排行榜、延时队列、按分数范围查。

```go
// 排行榜
redis.ZIncrBy(ctx, "liaison:rank:daily", 1, "user:123")
redis.ZRevRangeWithScores(ctx, "liaison:rank:daily", 0, 9)

// 延时队列：score = 执行时间戳
redis.ZAdd(ctx, "liaison:delay:queue", redis.Z{Score: float64(execAt), Member: jobID})
```

### List vs Stream

- **List**：简单 FIFO 队列，无消费组、无确认
- **Stream**：消费组、ack、回溯，**生产推荐**

## 大 Key 与热 Key

### 大 Key 红线

- 单 String value > 10 KB
- Hash / List / Set / Zset 元素数 > 5000
- Hash 单字段 > 1 KB

**后果**：扩容慢、阻塞、网络打满、删除卡住主线程。

```go
// ❌ 反例
redis.Set(ctx, "all_users", marshal(allUsers), 0) // 几 MB

// ✅ 拆分
for _, u := range users {
    redis.Set(ctx, fmt.Sprintf("liaison:user:%d", u.ID), marshal(u), time.Hour)
}
```

**已存在大 key**：用 `UNLINK` 异步删除，禁用 `DEL`。

### 热 Key 应对

- 多副本：`liaison:hot:counter:1` ~ `liaison:hot:counter:N`，写时随机、读时聚合
- 本地缓存（freecache / bigcache）兜底
- Lua 脚本合并多次操作

## 原子性：Lua 脚本

多步操作必须用 Lua 保证原子，禁止"先 GET 再 SET"。

```go
// ✅ 限流：原子的 INCR + EXPIRE
const rateLimitScript = `
local cur = redis.call("INCR", KEYS[1])
if cur == 1 then
  redis.call("EXPIRE", KEYS[1], ARGV[1])
end
return cur
`
n, err := redis.Eval(ctx, rateLimitScript, []string{"liaison:ratelimit:" + ip}, 60).Int()
if n > 100 { return ErrRateLimited }
```

## 分布式锁

```go
// ✅ SET NX EX + 唯一 owner + Lua 释放
owner := uuid.NewString()
ok, _ := redis.SetNX(ctx, "liaison:lock:order:123", owner, 30*time.Second).Result()
if !ok { return ErrLocked }
defer releaseLock(ctx, "liaison:lock:order:123", owner)

const releaseScript = `
if redis.call("GET", KEYS[1]) == ARGV[1] then
  return redis.call("DEL", KEYS[1])
else
  return 0
end
`
```

**红线：**
- 必须设 TTL（防止持有者崩溃后死锁）
- 释放必须校验 owner（防止释放别人的锁）
- 长任务用 `redsync` / `redislock` 等带续约的库
- 强一致场景考虑 etcd / ZooKeeper，Redis 锁是 best-effort

## 缓存三大问题

| 问题 | 含义 | 应对 |
|------|------|------|
| **穿透** | 查不存在的 key，每次打到 DB | 缓存空值（短 TTL）+ 布隆过滤器 |
| **击穿** | 单个热 key 过期瞬间，大量请求打 DB | 互斥锁重建 / 永不过期 + 后台刷新 |
| **雪崩** | 大量 key 同时过期 | TTL 加随机扰动（基础 TTL ± 10%） |

```go
// ✅ TTL 加扰动
ttl := baseTTL + time.Duration(rand.Intn(60))*time.Second
redis.Set(ctx, key, val, ttl)
```

## Pipeline / Batch

多次操作合并发送，减少 RTT：

```go
// ✅ Pipeline
pipe := redis.Pipeline()
for _, id := range ids {
    pipe.Get(ctx, fmt.Sprintf("liaison:user:%d", id))
}
results, _ := pipe.Exec(ctx)
```

**禁止**：在循环里逐条 `Get` / `Set`，会被网络 RTT 拖垮。

## Cluster 注意事项

- 单次命令的所有 key 必须在同一 slot，否则报错
- 用 hash tag 强制同 slot：`liaison:user:{12345}:profile` 和 `liaison:user:{12345}:quota` 在同 slot
- `MGET`、`MSET`、事务、Lua 都需要同 slot

## 持久化与可用性

- 缓存场景：RDB 即可（性能优先）
- 重要状态（消息队列、计数器）：AOF + everysec
- 高可用：哨兵 / Cluster
- **永远假设 Redis 可能数据丢失**：核心数据必须 MySQL 兜底

## 监控指标（详见 `10-observability/metrics.md`）

| 指标 | 告警阈值 |
|------|---------|
| 内存使用率 | > 80% |
| 命中率 | < 80% |
| 大 key 数量 | > 0 |
| 慢查询 | > 基线 2x |
| 主从延迟 | > 1s |
| 连接数 | > maxclients × 80% |

## 自查

- [ ] Key 有 namespace 前缀
- [ ] 所有 key 设了 TTL，例外有注释
- [ ] 数据类型选对（hash 用于字段独立更新、zset 用于排行）
- [ ] 无大 key（单 value < 10KB，集合元素 < 5000）
- [ ] 多步操作用 Lua 或事务，保证原子
- [ ] 分布式锁有 TTL + owner 校验
- [ ] 缓存有空值兜底 + TTL 扰动
- [ ] 批量操作用 pipeline
- [ ] Cluster 模式下用 hash tag 处理跨 key 操作
- [ ] 重要数据 MySQL 有兜底
