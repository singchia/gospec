# 10.4 - SLO 与告警规范

> 适用：定义服务 SLO、写告警规则、配置健康检查端点。

## SLI / SLO

### 推荐 SLI

| 服务类型 | SLI |
|---------|-----|
| HTTP API | 可用性（成功率）、延迟（P99） |
| 异步任务 | 处理成功率、积压时长 |
| 数据库 | 查询成功率、P99 延迟 |
| 第三方依赖 | 调用成功率、超时率 |

### 可用性目标 → 错误预算速查表

直接照抄到 `docs/slo/<service>.md`，避免重复算：

| 可用性目标 | 月度错误预算 | 周错误预算 | 说明 |
|-----------|-------------|-----------|------|
| 99% | ~7h 18min | ~1h 41min | MVP / 内部工具 |
| 99.5% | ~3h 39min | ~50min | 普通业务后台 |
| 99.9% | ~43min 12s | ~10min 5s | 一般对外服务（推荐起步） |
| 99.95% | ~21min 36s | ~5min 2s | 核心对外服务 |
| 99.99% | ~4min 19s | ~1min | 支付 / 关键链路 |
| 99.999% | ~26s | ~6s | 极少需要，成本陡增 |

### Burn Rate 告警阈值速查表

按 [Google SRE Workbook](https://sre.google/workbook/alerting-on-slos/) 的多窗口多 burn-rate 方案：

| 检测窗口 | Burn Rate | 多久耗尽 | 告警级别 | 触发例（99.9% SLO） |
|---------|-----------|---------|---------|-------------------|
| 5min + 1h | 14.4× | 2 天 | P0 | 1h 错误率 > 1.44% |
| 30min + 6h | 6× | 5 天 | P1 | 6h 错误率 > 0.6% |
| 2h + 24h | 3× | 10 天 | P2 | 24h 错误率 > 0.3% |
| 6h + 3d | 1× | 30 天 | P3（仅记录） | 3d 错误率 > 0.1% |

**双窗口要求**：长短窗口都越界才告警，避免单点抖动误报。

### SLO 模板

每个对外服务在 `docs/slo/<service>.md` 维护：

```markdown
# <服务名> SLO

## 服务等级目标
- 可用性：99.9%（月度，允许 ~43min 不可用）
- 延迟：P99 < 500ms（GET）/ < 1s（POST）
- 错误率：< 0.1%

## 错误预算
- 月度预算：0.1% × 30 天 = 43.2 分钟
- 消耗 50% 预警，80% 冻结非紧急发布

## 告警规则
- burn rate > 14.4×（1h 窗口）→ P0
- burn rate > 6×（6h 窗口）→ P1
```

参考：[Google SRE Workbook - Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)

---

## 告警分级

| 级别 | 响应时间 | 通知方式 | 示例 |
|------|---------|---------|------|
| P0 | 5 min | 电话 + 短信 + IM | 服务不可用、数据损坏 |
| P1 | 15 min | 短信 + IM | SLO 即将耗尽、核心降级 |
| P2 | 1 h | IM | 部分功能异常、依赖降级 |
| P3 | 工作日 | 邮件 / 工单 | 容量预警、证书过期 |

## 告警设计原则

1. **可执行**：每条告警必须有对应 Runbook 链接
2. **基于症状非原因**：告警"用户登录失败率上升"，不是"数据库 CPU 高"
3. **避免疲劳**：聚合相似告警、设置静默窗口
4. **可关闭**：定期 review 历史告警，删除噪音规则

## 告警规则示例

```yaml
- alert: HighHttpErrorRate
  expr: |
    sum(rate(order_http_errors_total[5m]))
      / sum(rate(order_http_requests_total[5m])) > 0.05
  for: 5m
  labels:
    severity: P1
  annotations:
    summary: "HTTP 错误率 > 5%"
    runbook_url: "https://wiki.internal/runbooks/http-error-rate"
```

---

## 健康检查端点

每个服务必须暴露：

| 端点 | 用途 | 检查内容 |
|------|------|---------|
| `/healthz` | 存活探针（liveness） | 进程能响应（不依赖外部） |
| `/readyz` | 就绪探针（readiness） | DB、缓存、必需依赖可用 |
| `/metrics` | Prometheus 抓取 | 指标暴露 |
| `/debug/pprof/` | 性能剖析 | 仅内网开放，需鉴权 |

```go
// ✅ 推荐：readyz 实际检查依赖
func (s *Server) handleReadyz(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
    defer cancel()
    if err := s.dao.PingContext(ctx); err != nil {
        http.Error(w, "db not ready", http.StatusServiceUnavailable)
        return
    }
    w.WriteHeader(http.StatusOK)
}
```

## 自查

- [ ] 对外服务有 SLO 文档
- [ ] 告警规则配 Runbook 链接（见 `12-operations/incident.md`）
- [ ] `/healthz` 不依赖外部
- [ ] `/readyz` 真实检查依赖
- [ ] 新增依赖已加入 `/readyz`
