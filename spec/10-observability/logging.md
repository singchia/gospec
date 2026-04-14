# 10.1 - 日志规范

> 适用：写代码时需要打日志、决定日志级别、处理敏感信息。

## 技术选型

| 用途 | 选型 |
|------|------|
| 日志库 | `log/slog`（Go 1.21+）或 `zap` |
| 输出格式 | JSON（生产）/ Text（本地） |
| 日志轮转 | `lumberjack` 或交给容器/sidecar |

## 结构化输出

```go
// ✅ 推荐
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))

logger.InfoContext(ctx, "edge created",
    slog.String("trace_id", traceIDFromCtx(ctx)),
    slog.Int64("user_id", user.ID),
    slog.Int64("edge_id", edge.ID),
    slog.Duration("cost", time.Since(start)),
)

// ❌ 禁止：拼接字符串
log.Printf("user %d created edge %d in %v", user.ID, edge.ID, cost)
```

## 日志级别使用边界

| 级别 | 场景 | 示例 |
|------|------|------|
| `DEBUG` | 详细调试，生产关闭 | SQL 语句、函数入参出参 |
| `INFO` | 业务里程碑 | 用户登录成功、订单创建成功 |
| `WARN` | 可恢复异常 | 重试成功、降级触发、配额接近上限 |
| `ERROR` | 不可恢复错误 | 数据库连接失败、第三方 API 超时 |

**规则：**
- `ERROR` 必须包含完整 error chain（`%w` 包装）
- 同一错误只在最外层记录一次，避免日志风暴
- 高频路径（>100 QPS）禁用 `INFO` 级别
- 禁用 FATAL/PANIC（除 main 初始化外）

## 必填字段

每条日志必须包含：

```json
{
  "time": "2026-04-14T10:30:45.123Z",
  "level": "INFO",
  "msg": "edge created",
  "service": "liaison-manager",
  "version": "v1.2.3",
  "trace_id": "abc123...",
  "span_id": "def456...",
  "caller": "controlplane/edge.go:45"
}
```

业务字段按需添加：`user_id`、`tenant_id`、`request_id`、`http.method`、`http.status`。

## 敏感信息脱敏

```go
// ✅ 推荐：实现 LogValuer 接口自动脱敏
type RedactedUser struct {
    ID    int64
    Email string
}

func (u RedactedUser) LogValue() slog.Value {
    return slog.GroupValue(
        slog.Int64("id", u.ID),
        slog.String("email", maskEmail(u.Email)),
    )
}

func maskEmail(s string) string {
    parts := strings.SplitN(s, "@", 2)
    if len(parts) != 2 || len(parts[0]) == 0 { return s }
    return parts[0][:1] + "***@" + parts[1]
}
```

**禁止字段**：`password` / `token` / `secret` / `authorization` / `id_card` / `phone`（明文）

## 反模式

- ❌ 在循环里打 INFO（用 sampling 或聚合）
- ❌ 打日志后再 return error（重复记录）
- ❌ 把整个 request body 打进日志
- ❌ 用 `panic` 代替 `ERROR` 日志

## 自查

- [ ] 关键路径有 INFO，错误路径有 ERROR
- [ ] 日志包含 `trace_id` 和业务关联字段
- [ ] 无敏感字段明文输出
- [ ] 同一错误不在多层重复记录
