# 04.4 - InfluxDB

> **适用**：设计 InfluxDB measurement、决定 tag/field、配 retention policy、做监控指标 / IoT 时序数据存储。
>
> InfluxDB 是**纯时序数据库**。设计的核心是控制 series 基数。

## 何时用 InfluxDB

| 场景 | ✅ 适合 | ❌ 不适合 |
|------|--------|----------|
| 服务监控指标 | ✅ | |
| IoT 设备上报 | ✅ | |
| 业务实时大盘 | ✅ | |
| 多维分析（高基数维度） | | ❌ 用 ClickHouse |
| 明细日志 | | ❌ 用 ClickHouse / ES |
| 主数据 / 事务 | | ❌ 用 MySQL |

> **版本说明**：本规范以 **InfluxDB 2.x（Flux + bucket）** 为主，1.x（InfluxQL + database/RP）原理相通，命令略不同。

## 数据模型

```
measurement,tag1=v1,tag2=v2 field1=1.0,field2=2.0 timestamp
```

| 概念 | 类比 SQL | 索引 | 说明 |
|------|---------|------|------|
| **measurement** | 表名 | — | 业务实体（如 `cpu`、`device_metric`） |
| **tag** | 索引列 | ✅ 索引 | 用于过滤 / group by，**必须低基数** |
| **field** | 数据列 | ❌ 不索引 | 实际度量值 |
| **timestamp** | 时间 | ✅ 索引 | 必填 |
| **series** | 行（按 tag 组合） | — | 同一组 tag 值 = 一个 series |

## Tag 与 Field 的红线

### Tag = 低基数维度

✅ **可以**：
- 服务名、主机名、机房、地区
- 设备型号、协议类型
- HTTP method、status_code（只有几十种）
- tenant_id（如果 tenant 数 < 几千）

❌ **禁止**：
- `user_id`、`request_id`、`session_id`、`order_id`（高基数 → series 爆炸）
- `email`、`url`、`ip`（无界）
- 时间戳、精度高的浮点数

### Field = 度量值或不需要过滤的字符串

```
cpu,host=web01,region=cn-north field_value=85.5,used_pct=0.85 1731234567000000000
http_request,service=liaison,method=GET,status=200 latency_ms=23.5,bytes=1024 1731234567000000000
```

### Series 基数估算

```
total_series = ∏ (每个 tag 的 cardinality)
```

**经验阈值**：
- 单 measurement 总 series 数 < 100 万
- 全库 series 数 < 1000 万
- 超过会内存爆 / 写入慢 / 查询慢

```
# ❌ 反例
http_request,user_id=12345,url=/api/v1/edges/67890 latency=23
# user_id × url = 千万 × 万 = 千亿 series → 爆炸

# ✅ 正确
http_request,service=liaison,route=/api/v1/edges/:id,method=GET,status=200 latency=23,user_count=1
# user_id 不进 tag；如需关联，写日志 / ClickHouse
```

## Measurement 命名

```
<domain>_<entity>_<metric>
```

| 部分 | 说明 | 示例 |
|------|------|------|
| domain | 业务域 | `liaison` / `iot` |
| entity | 实体 | `device` / `edge` / `http` |
| metric | 度量类型 | `metric` / `event` / `latency` |

```
# ✅
liaison_http_request
liaison_edge_status
iot_device_metric

# ❌
HttpRequest          # 应该 snake_case
http                 # 没 namespace
device_status_data   # data 是冗余
```

## Bucket 与 Retention（2.x）

```
# 创建 bucket，TTL 30 天
influx bucket create -n liaison-metrics -r 30d
```

| 数据类型 | 推荐 retention |
|---------|---------------|
| 高精度原始指标 | 7-30 天 |
| 5min 降采样 | 90 天 |
| 1h 降采样 | 1-2 年 |
| 1d 降采样 | 5 年 |

## 降采样（Downsampling）

原始数据成本高，长期存储用降采样。InfluxDB 2.x 用 **Task** 实现：

```flux
option task = {name: "downsample-5min", every: 5m}

from(bucket: "liaison-metrics")
  |> range(start: -10m)
  |> filter(fn: (r) => r._measurement == "http_request")
  |> aggregateWindow(every: 5m, fn: mean, createEmpty: false)
  |> set(key: "_measurement", value: "http_request_5min")
  |> to(bucket: "liaison-metrics-90d")
```

InfluxDB 1.x 用 **Continuous Query**。

---

## 写入规范

### 必须批量

```go
// ✅ 批量写入，每批 5K-10K 点
client := influxdb2.NewClient(url, token)
writeAPI := client.WriteAPI("org", "liaison-metrics")

points := make([]*write.Point, 0, 5000)
for ev := range eventCh {
    p := influxdb2.NewPoint(
        "http_request",
        map[string]string{ // tags
            "service": "liaison",
            "method":  ev.Method,
            "status":  fmt.Sprintf("%d", ev.Status),
        },
        map[string]interface{}{ // fields
            "latency_ms": ev.LatencyMs,
            "bytes":      ev.Bytes,
        },
        ev.Time,
    )
    points = append(points, p)
    if len(points) >= 5000 {
        for _, p := range points { writeAPI.WritePoint(p) }
        points = points[:0]
    }
}
writeAPI.Flush()
```

### Line Protocol

```
http_request,service=liaison,method=GET,status=200 latency_ms=23.5,bytes=1024i 1731234567000000000
```

- `i` 后缀表示整数（避免被推断为 float）
- 时间戳精度默认纳秒，写入时统一精度
- 字段顺序：measurement → tags（按 key 排序）→ fields → timestamp

### 禁止事项

- ❌ 单点写入（性能差 1000 倍）
- ❌ 频繁修改 schema（增减 tag 会产生新 series）
- ❌ 把日志 message 当 field（用 ClickHouse / ES）

---

## 查询规范

### Flux（2.x）

```flux
from(bucket: "liaison-metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "http_request")
  |> filter(fn: (r) => r.service == "liaison" and r.status == "500")
  |> aggregateWindow(every: 1m, fn: count)
  |> yield(name: "error_count")
```

**规则：**
- `range()` 必须有，且**越窄越好**
- `filter()` 优先按 tag 过滤
- 聚合用 `aggregateWindow()`，避免 `pivot` 在原始数据上跑

### 反模式

```flux
// ❌ 没有 range：扫全 bucket
from(bucket: "liaison-metrics")
  |> filter(fn: (r) => r.service == "liaison")
```

---

## 监控指标自身的可观测性

| 指标 | 告警阈值 |
|------|---------|
| series 基数 | > 阈值 80% |
| 写入失败率 | > 0.1% |
| 写入延迟 | P99 > 1s |
| 内存使用 | > 80% |
| 磁盘使用 | > 80% |

通用监控规范见 `10-observability/metrics.md`（Prometheus 路线）。**InfluxDB 适合做长期存储 + 多维聚合，Prometheus 适合做短期高频抓取 + 告警**。两者可以共存。

## 与 Prometheus 的关系

| 维度 | Prometheus | InfluxDB |
|------|-----------|----------|
| 数据来源 | 主动拉取（pull） | 客户端推送（push） |
| 存储时长 | 天/周（默认 15 天） | 月/年 |
| 维度基数 | 中等 | 严格控制 |
| 查询语言 | PromQL | InfluxQL / Flux |
| 适用 | 服务监控 + 告警 | 业务指标 + 长期分析 + IoT |

常见组合：Prometheus 抓取 → Remote Write 到 InfluxDB / VictoriaMetrics 长期存。

## 自查

- [ ] Tag 全部低基数（< 1000，最好 < 100）
- [ ] 高基数维度（user_id、url）放 field 或不进 InfluxDB
- [ ] Series 基数估算 < 100 万 / measurement
- [ ] Measurement 命名 snake_case + namespace
- [ ] Bucket 有 retention policy
- [ ] 长期数据有降采样 task
- [ ] 写入批量（每批 ≥ 1000 点）
- [ ] 查询有窄 `range()`
- [ ] schema 稳定，不频繁增减 tag
