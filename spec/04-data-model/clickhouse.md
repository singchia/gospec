# 04.3 - ClickHouse

> **适用**：设计 ClickHouse 表、选 engine、写聚合查询、做日志/分析/报表。
>
> ClickHouse 是 OLAP 列存数据库。**不要把它当 MySQL 用**：不擅长高频 UPDATE、强一致事务、点查。

## 何时用 ClickHouse

| 场景 | ✅ 适合 | ❌ 不适合 |
|------|--------|----------|
| 海量明细日志、事件 | ✅ | |
| 时间序列数据（带维度聚合） | ✅ | InfluxDB 更适合纯指标 |
| 报表 / BI / 数据分析 | ✅ | |
| 实时大盘 | ✅ | |
| OLTP 事务 | | ❌ 用 MySQL |
| 高频 UPDATE / DELETE | | ❌ |
| 点查（按主键查单行） | | ❌ 用 MySQL/Redis |
| 强外键关联 | | ❌ |

## 表 Engine 选择

### MergeTree 家族（生产唯一选项）

| Engine | 用途 |
|--------|------|
| **MergeTree** | 通用，append-only 明细 |
| **ReplacingMergeTree** | 按主键去重（最终一致，不保证立即生效） |
| **SummingMergeTree** | 按主键自动求和（预聚合） |
| **AggregatingMergeTree** | 任意聚合函数预聚合 |
| **CollapsingMergeTree** | 通过 sign 列折叠行（实现"删除"语义） |
| **ReplicatedXxx** | 上述任一种 + 副本，**生产必须用 Replicated** |

### 命名模板

```sql
CREATE TABLE foo.events_local ON CLUSTER '{cluster}'
(
    event_time   DateTime64(3, 'UTC'),
    event_date   Date DEFAULT toDate(event_time),
    tenant_id    UInt64,
    user_id      UInt64,
    event_type   LowCardinality(String),
    order_id     UInt64,
    duration_ms  UInt32,
    metadata     String CODEC(ZSTD(3))
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/events', '{replica}')
PARTITION BY toYYYYMM(event_date)
ORDER BY (tenant_id, event_type, event_time)
TTL event_date + INTERVAL 90 DAY
SETTINGS index_granularity = 8192;
```

**分布式视图**（如果分片）：

```sql
CREATE TABLE foo.events ON CLUSTER '{cluster}' AS foo.events_local
ENGINE = Distributed('{cluster}', foo, events_local, rand());
```

## 设计原则

### 1. ORDER BY 是主键，决定查询性能

- ORDER BY 列从**低基数到高基数**排列
- 把最常用的过滤条件放最前面
- 时间字段几乎总是放最后

```sql
-- ✅ 正确：tenant_id 是高频过滤，event_time 用于范围扫
ORDER BY (tenant_id, event_type, event_time)

-- ❌ 错误：把 event_time 放最前，按 tenant 查时全表扫
ORDER BY (event_time, tenant_id, event_type)
```

### 2. PARTITION BY 不是越细越好

- 推荐按月 `toYYYYMM(date)` 或按日 `toYYYYMMDD(date)`
- 单表分区数建议 < 1000
- ❌ 禁止按高基数列分区（按 user_id 分区会爆炸）

### 3. 用 LowCardinality 包字符串枚举

```sql
event_type LowCardinality(String)  -- 几十种取值，省内存
```

适用于取值数 < 10000 的字符串列。

### 4. 数据类型尽量小

| 用途 | 推荐 |
|------|------|
| 整数 ID | `UInt32` / `UInt64` |
| 时间戳 | `DateTime64(3)`（毫秒）/ `DateTime`（秒） |
| 枚举 | `LowCardinality(String)` 或 `Enum8` |
| IP | `IPv4` / `IPv6` |
| JSON | 优先拆字段，必须存 JSON 用 `String CODEC(ZSTD)` |

### 5. 数据保留：TTL

```sql
TTL event_date + INTERVAL 90 DAY DELETE,
    event_date + INTERVAL 30 DAY TO VOLUME 'cold'  -- 分层存储
```

数据治理策略详见 `13-database-migration/data-governance.md`。

---

## 写入规范

### 必须批量写入

```go
// ✅ 推荐：批量 INSERT，每批 10K-100K 行
batch := make([]Event, 0, 50000)
for evt := range eventCh {
    batch = append(batch, evt)
    if len(batch) >= 50000 {
        chConn.AsyncInsert(ctx, "INSERT INTO foo.events_local VALUES", false, batch...)
        batch = batch[:0]
    }
}
```

- 单次写入 > 1000 行
- 写入频率 < 1 次/秒/表（否则会触发过多 Merge）
- 高并发写用 **Buffer 表** 或 **Async Insert** 或 Kafka 中转

```sql
-- Buffer 表自动批量
CREATE TABLE foo.events_buffer AS foo.events_local
ENGINE = Buffer('foo', 'events_local', 16, 10, 60, 10000, 100000, 10000000, 100000000);
```

### 禁止事项

- ❌ 一次插入 1 行
- ❌ 高频写入触发器 / 物化视图链
- ❌ 业务高峰期跑 OPTIMIZE FINAL

---

## 查询规范

### 使用主键过滤

```sql
-- ✅ 命中主键索引
SELECT * FROM events
WHERE tenant_id = 100 AND event_type = 'login'
  AND event_time BETWEEN '2026-04-01' AND '2026-04-14';

-- ❌ 跳过主键最左列，全表扫
SELECT * FROM events WHERE event_type = 'login';
```

### 避免 SELECT *

列存数据库，**只读需要的列**：

```sql
-- ✅
SELECT event_time, user_id, duration_ms FROM events WHERE ...

-- ❌ 把所有列都读出来，浪费 IO
SELECT * FROM events WHERE ...
```

### 大表 JOIN 用 dictionary 或 IN 子查询

```sql
-- ❌ 大表 JOIN 大表，性能差
SELECT * FROM events e JOIN users u ON e.user_id = u.id;

-- ✅ 用字典
CREATE DICTIONARY users_dict (...) PRIMARY KEY id ...;
SELECT event_time, dictGet('users_dict', 'name', user_id) FROM events;

-- ✅ 或 IN 子查询
SELECT * FROM events WHERE user_id IN (SELECT id FROM users WHERE country = 'CN');
```

### 聚合查询

```sql
-- ✅ 用 quantile 系列函数
SELECT
    event_type,
    count() AS cnt,
    quantile(0.99)(duration_ms) AS p99,
    quantile(0.5)(duration_ms) AS p50
FROM events
WHERE event_time >= now() - INTERVAL 1 HOUR
GROUP BY event_type;
```

---

## 物化视图（Materialized View）

预聚合明细 → 加速查询。

```sql
CREATE MATERIALIZED VIEW foo.events_5min_mv
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(t)
ORDER BY (tenant_id, event_type, t)
AS SELECT
    toStartOfFiveMinute(event_time) AS t,
    tenant_id,
    event_type,
    count() AS cnt,
    sum(duration_ms) AS total_duration
FROM foo.events_local
GROUP BY t, tenant_id, event_type;
```

**注意**：物化视图是**触发器**，新数据写入源表时同步触发。删除/重建源表会破坏视图。

---

## 副本与分片

### 副本（Replicated）

生产**必须**用 Replicated 系列 engine，配 ZooKeeper / ClickHouse Keeper。

### 分片

数据量大才需要：

- 单分片建议 < 1 TB
- 分片键用业务自然键（tenant_id），保证查询能落到单分片
- 跨分片查询通过 Distributed 表

---

## 监控（详见 `10-observability/metrics.md`）

| 指标 | 告警阈值 |
|------|---------|
| Merge 队列积压 | > 100 |
| 副本延迟 | > 30 s |
| Mutation 队列 | > 10 |
| 内存使用率 | > 80% |
| 单查询耗时 | P99 > SLO |
| Parts 数量 | > 300 / partition |

## 自查

- [ ] Engine 选 MergeTree 家族 + Replicated
- [ ] ORDER BY 从低基数到高基数
- [ ] 时间分区粒度合理（月 / 日）
- [ ] 字符串枚举用 LowCardinality
- [ ] 整数选最小够用的类型
- [ ] 表有 TTL 自动清理
- [ ] 写入是批量 / Buffer 表 / Async Insert
- [ ] 查询命中主键过滤
- [ ] 不写 SELECT *
- [ ] 大表 JOIN 改字典或 IN
- [ ] 高频聚合走物化视图
