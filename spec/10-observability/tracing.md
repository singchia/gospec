# 10.3 - 链路追踪规范

> 适用：写跨服务调用、数据库/缓存访问、关键业务节点时，需要埋点 span。

## 技术选型

- **协议**：OpenTelemetry（OTel）— 厂商无关
- **SDK**：`go.opentelemetry.io/otel`
- **后端**：Jaeger / Tempo / SkyWalking 任选

## 必须埋点的位置

1. HTTP / gRPC 入口（自动通过 middleware）
2. 出口调用：DB、Redis、第三方 HTTP、消息队列
3. 关键业务节点：事务、批处理、加解密

## 使用示例

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/codes"
)

var tracer = otel.Tracer("order/biz")

func (uc *OrderUsecase) CreateOrder(ctx context.Context, input *CreateOrderInput) (*Order, error) {
    ctx, span := tracer.Start(ctx, "OrderUsecase.CreateOrder")
    defer span.End()

    span.SetAttributes(
        attribute.Int64("user.id", userIDFromCtx(ctx)),
        attribute.String("order.name", input.Name),
    )

    order, err := uc.repo.Create(ctx, input)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        return nil, err
    }
    span.SetAttributes(attribute.Int64("order.id", order.ID))
    return order, nil
}
```

## Span 命名规范

```
<package>.<Type>.<Method>     // 业务代码
HTTP <METHOD> <route>          // HTTP 入口
DB <operation> <table>         // 数据库
<service>.<rpc>                // RPC 调用
```

## Context 传播

```go
// ✅ 推荐：trace_id 自动注入日志
func loggerFromCtx(ctx context.Context) *slog.Logger {
    span := trace.SpanFromContext(ctx)
    return slog.With(
        slog.String("trace_id", span.SpanContext().TraceID().String()),
        slog.String("span_id", span.SpanContext().SpanID().String()),
    )
}
```

**规则：**
- HTTP 入口 middleware 必须解析 `traceparent` header
- 跨服务调用必须把 trace context 注入下游请求
- 数据库、Redis、MQ 客户端启用 OTel instrumentation

## 采样策略

- **开发**：100% 采样
- **生产**：1%~10% 头部采样 + 100% 错误采样（tail-based sampling）
- 关键业务路径可独立配置高采样率

## 自查

- [ ] 出口调用（DB/HTTP/MQ）已被 tracing 覆盖
- [ ] Span 命名遵循约定，包含业务关键属性
- [ ] 错误路径调用 `RecordError` + `SetStatus`
- [ ] 跨服务 context 正确传播
