# 10 - 可观测性

> Logs + Metrics + Traces 三位一体。生产事故定位时间的瓶颈在"找现场"，可观测性的目的是把这个时间压缩到分钟级。

## 何时读哪个

| 当前任务 | 读这个 |
|---------|--------|
| 加日志、决定日志级别、脱敏 | `logging.md` |
| 加 Prometheus 指标、命名、label | `metrics.md` |
| 加 OpenTelemetry span、跨服务上下文 | `tracing.md` |
| 写告警规则、定义 SLO、健康检查端点 | `slo-alerting.md` |

## 核心原则（全局）

1. **三大支柱缺一不可**：日志看事件，指标看趋势，链路看因果
2. **统一上下文**：所有信号通过 `trace_id` 串联
3. **结构化优先**：禁止 `fmt.Printf` 风格的纯文本日志
4. **就近采集，集中分析**：应用只输出，采集和聚合交给 sidecar/agent
5. **敏感信息脱敏**：密码、token、身份证、手机号在日志层就过滤

## 强制约束（不可违反）

- 所有对外服务必须暴露 `/healthz`、`/readyz`、`/metrics`
- 日志结构化 + `trace_id`，ERROR 日志包含完整 error chain
- 高基数字段（user_id、email）禁止作为 Prometheus label
- 敏感字段禁止明文入日志
- 每条告警必须配 Runbook 链接（详见 `12-operations/incident.md`）
