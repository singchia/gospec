# 10.2 - 指标规范

> 适用：写代码时需要埋 Prometheus 指标、设计仪表盘。

## 技术选型

- **采集**：`prometheus/client_golang`
- **暴露**：`/metrics` HTTP 端点
- **存储**：Prometheus / VictoriaMetrics
- **可视化**：Grafana

## 命名规范

遵循 [Prometheus 官方约定](https://prometheus.io/docs/practices/naming/)：

```
<namespace>_<subsystem>_<name>_<unit>
```

| 部分 | 说明 | 示例 |
|------|------|------|
| namespace | 服务名 | `liaison` |
| subsystem | 模块名 | `iam` / `edge` / `dao` |
| name | 度量含义 | `requests` / `errors` / `duration` |
| unit | 单位（必填） | `_total` / `_seconds` / `_bytes` |

```
# ✅ 正确
liaison_iam_login_requests_total
liaison_dao_query_duration_seconds
liaison_edge_active_connections

# ❌ 错误
loginCount         # 缺 namespace、单位、复数
api_latency_ms     # 应使用 _seconds（Prometheus 约定）
```

## 必埋指标（RED + USE）

**RED — 面向请求的服务**

| 指标 | 类型 | 示例 label |
|------|------|-----------|
| **R**ate | Counter | `xxx_requests_total{method,route,status}` |
| **E**rrors | Counter | `xxx_errors_total{method,route,code}` |
| **D**uration | Histogram | `xxx_request_duration_seconds{method,route}` |

**USE — 面向资源**：Utilization / Saturation / Errors（CPU、内存、连接池、队列长度）

## 实现示例

```go
import "github.com/prometheus/client_golang/prometheus"

var (
    httpRequests = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Namespace: "liaison",
            Subsystem: "http",
            Name:      "requests_total",
            Help:      "Total HTTP requests processed.",
        },
        []string{"method", "route", "status"},
    )

    httpDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Namespace: "liaison",
            Subsystem: "http",
            Name:      "request_duration_seconds",
            Help:      "HTTP request latency.",
            Buckets:   []float64{.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
        },
        []string{"method", "route"},
    )
)

func init() {
    prometheus.MustRegister(httpRequests, httpDuration)
}
```

## Label 红线

- ❌ **高基数 label**：`user_id`、`request_id`、`email`（导致时序爆炸）
- ❌ **动态 label 值**：`route="/api/v1/users/12345"`，应聚合为 `route="/api/v1/users/:id"`
- ✅ 单个指标的 label 组合数 < 1 万

## 自查

- [ ] 对外服务有 RED 三件套
- [ ] 指标命名包含 namespace + subsystem + name + unit
- [ ] 无高基数 label
- [ ] Histogram bucket 覆盖业务 P99 范围
