# 05.2 - 错误处理

> **适用**：返回错误、判断错误、包装错误、决定 panic / log / return。

## 三大原则

1. **每个错误必须被处理**：禁止 `_ = someFunc()` 忽略
2. **错误不重复记录**：要么处理并记录，要么向上传播，不能两者都做
3. **错误信息保留上下文**：用 `%w` 包装

## 哨兵错误（Sentinel Errors）

```go
// ✅ 在 internal/pkg/errs 或各 BC 的 biz 包定义领域错误
package errs

var (
    ErrInvalidInput  = errors.New("invalid input")
    ErrNotFound      = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
    ErrUnauthorized  = errors.New("unauthorized")
)

// ✅ 使用 errors.Is() 判断
if errors.Is(err, errs.ErrInvalidInput) {
    return // 正常退出，不记录日志
}
```

## 错误包装

```go
// ✅ fmt.Errorf + %w 保留上下文
if err != nil {
    return fmt.Errorf("create order %q: %w", req.Name, err)
}

// ✅ errors.Is() 检查整条错误链
if errors.Is(err, gorm.ErrRecordNotFound) {
    return nil, errs.ErrNotFound
}

// ✅ errors.As() 提取具体错误类型
var pqErr *pq.Error
if errors.As(err, &pqErr) && pqErr.Code == "23505" {
    return nil, errs.ErrAlreadyExists
}
```

**规则：**
- 包装时**只在加上下文时包装**，没新信息就直接返回
- 错误链消息不要重复（`fmt.Errorf("foo: %w", fmt.Errorf("foo: %w", err))` 是反模式）
- 不要 `fmt.Errorf("%v", err)`（丢失链）—— 必须 `%w`

## 错误类型化

需要携带额外信息时定义 error 类型：

```go
// ✅ 自定义 error 类型
type ValidationError struct {
    Field string
    Value interface{}
    Rule  string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed: field=%s value=%v rule=%s", e.Field, e.Value, e.Rule)
}

// 调用方
var vErr *ValidationError
if errors.As(err, &vErr) {
    return badRequest(vErr.Field, vErr.Rule)
}
```

## 错误处理决策树

```
err != nil
  ├─ 是不可恢复的初始化失败？
  │    └─ 在 main 范围内 panic 或退出
  ├─ 是预期错误（NotFound / AlreadyExists / Validation）？
  │    └─ 包装后向上传播，由上层决定如何响应
  ├─ 是意外错误（DB 连接断 / 第三方超时）？
  │    └─ 记录 ERROR 日志（含 trace_id、上下文）+ 包装传播
  └─ 是正常退出信号（context.Canceled、业务无错误的早返回）？
       └─ 静默处理，不记录日志
```

## panic 与 recover

```go
// ❌ 业务逻辑禁止 panic
func CreateOrder(req *Request) (*Order, error) {
    if req == nil {
        panic("nil request")  // 反例
    }
}

// ✅ 返回错误
if req == nil {
    return nil, errors.New("nil request")
}

// ✅ goroutine 中必须 recover panic
go func() {
    defer func() {
        if r := recover(); r != nil {
            stack := debug.Stack()
            slog.Error("panic recovered",
                slog.Any("panic", r),
                slog.String("stack", string(stack)),
            )
        }
    }()
    // ...
}()
```

**何时允许 panic：**
- main 初始化失败（无法继续）
- 程序员错误（不可能发生的逻辑分支）—— 此时 panic 比 nil error 更安全
- 第三方库要求实现的接口（如 `MarshalJSON` 内部错误）

## 错误与日志的边界

```go
// ❌ 反例：错误被记录两遍
func (uc *OrderUsecase) CreateOrder(ctx context.Context, in *Input) error {
    if err := uc.repo.Create(ctx, order); err != nil {
        slog.Error("data create failed", "err", err)  // 这里记一次
        return err                                    // 上层又会记一次
    }
}

// ✅ 要么记录要么传播，二选一
func (uc *OrderUsecase) CreateOrder(ctx context.Context, in *Input) error {
    if err := uc.repo.Create(ctx, order); err != nil {
        return fmt.Errorf("data create order: %w", err)
    }
}

// 在最外层（Handler）记录一次
func (s *OrderService) CreateOrder(ctx context.Context, req *Request) (*Response, error) {
    resp, err := s.uc.CreateOrder(ctx, toInput(req))
    if err != nil {
        slog.ErrorContext(ctx, "create order failed",
            slog.String("trace_id", traceIDFromCtx(ctx)),
            slog.Any("err", err),
        )
        return nil, err
    }
    return resp, nil
}
```

详见 `10-observability/logging.md`。

## HTTP 错误映射

```go
// ✅ 领域错误 → HTTP 错误码（Kratos 风格；gin / hertz API 不同，职责一致）
import kratoserrors "github.com/go-kratos/kratos/v2/errors"

if errors.Is(err, errs.ErrNotFound) {
    return nil, kratoserrors.New(404, "ORDER_NOT_FOUND", "订单不存在")
}
if errors.Is(err, errs.ErrAlreadyExists) {
    return nil, kratoserrors.New(409, "ORDER_ALREADY_EXISTS", "订单已存在")
}
return nil, err // 其他透传为 500
```

详见 `03-api/http.md` 错误映射章节。

## 自查

- [ ] 无 `_ = fn()` 忽略错误
- [ ] 错误用 `%w` 包装，不用 `%v`
- [ ] 同一错误不重复记录
- [ ] 业务逻辑无 panic
- [ ] goroutine 有 recover
- [ ] 错误链可被 `errors.Is` / `errors.As` 检查
