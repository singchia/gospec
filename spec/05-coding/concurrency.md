# 05.3 - 并发

> **适用**：写 goroutine、用 mutex / RWMutex、传 context、用 channel、控制并发数。
>
> 高级并发模式（worker pool、pipeline、errgroup、retry）见 `patterns.md`。

## goroutine 管理

```go
// ✅ goroutine 退出时 recover panic
go func() {
    defer func() {
        if r := recover(); r != nil {
            slog.Error("panic recovered", slog.Any("panic", r))
        }
    }()
    // ...
}()
```

**红线：**
- ❌ 不能在 goroutine 中无 recover
- ❌ 不能启动无退出条件的 goroutine（导致泄漏）
- ❌ 不能在 goroutine 中访问未加锁的共享状态
- ❌ 不能 fire-and-forget 而不知道它何时结束

### 退出条件

每个 goroutine 都要有明确的退出条件：

```go
// ✅ 通过 context 取消
func (w *Worker) Run(ctx context.Context) {
    for {
        select {
        case <-ctx.Done():
            return
        case task := <-w.tasks:
            w.process(ctx, task)
        }
    }
}

// ✅ 通过 done channel
func (s *Server) Loop(done <-chan struct{}) {
    for {
        select {
        case <-done:
            return
        // ...
        }
    }
}
```

## 锁

### Mutex / RWMutex

```go
// ✅ 读写锁保护共享状态
type Service struct {
    mu    sync.RWMutex
    cache map[string]string
}

func (s *Service) Get(key string) string {
    s.mu.RLock()
    defer s.mu.RUnlock()
    return s.cache[key]
}

func (s *Service) Set(key, val string) {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.cache[key] = val
}
```

### 锁红线

- ❌ 禁止把 mutex 嵌入到要拷贝的结构体（拷贝后锁失效）
- ❌ 禁止持有锁时调用外部函数 / 第三方 API（容易死锁）
- ❌ 禁止持有锁时阻塞（如 `time.Sleep`、IO）
- ❌ 禁止同一函数内 `Lock` 然后 `RLock`（重入会死锁，sync.Mutex 不可重入）
- ✅ 锁的粒度尽可能小：只保护共享状态，不保护业务逻辑
- ✅ defer 释放锁，避免分支提前 return 漏放

### 何时不用锁

- **`sync/atomic`**：单个数值的原子读写
- **channel**：goroutine 间通信
- **`sync.Map`**：读多写少，且 key 不固定
- **不可变数据**：初始化后不变

```go
// ✅ atomic 计数器
var counter int64
atomic.AddInt64(&counter, 1)
val := atomic.LoadInt64(&counter)
```

## context

### 三大用途

1. **取消信号**：上游取消后，下游所有 goroutine 退出
2. **截止时间**：`WithTimeout` / `WithDeadline`
3. **请求作用域的值**：`context.WithValue`（仅限请求级元数据：trace_id、user）

### 规则

```go
// ✅ context 是函数第一个参数
func (s *Service) CreateEdge(ctx context.Context, req *Request) (*Response, error)

// ✅ 入口生成 context，下游传递
func main() {
    ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
    defer cancel()
    server.Run(ctx)
}

// ✅ 设置超时
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()
return s.dao.Query(ctx, sql)
```

### context 红线

- ❌ 禁止 `context.Background()` 在非 main / test 入口使用
- ❌ 禁止 context 存储可变状态
- ❌ 禁止 context 传业务参数（应该走函数参数）
- ❌ 禁止忘记调用 `cancel()`（资源泄漏）
- ❌ 禁止把 context 存入 struct 字段（除非确实是 long-lived 服务的根 context）

```go
// ❌ 反例
type Service struct {
    ctx context.Context  // 不要这样
}

// ✅ 正例
type Service struct {
    // 没有 context 字段
}
func (s *Service) Do(ctx context.Context) {}
```

### 取消信号传播

```go
// ✅ 下游必须尊重取消
func (s *Service) Process(ctx context.Context) error {
    for _, item := range items {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
        }
        if err := s.processOne(ctx, item); err != nil {
            return err
        }
    }
    return nil
}
```

## channel

### 选择 channel 还是锁

| 场景 | 推荐 |
|------|------|
| 共享一份数据 | 锁 |
| 传递所有权 / 在 goroutine 间转移数据 | channel |
| 计数 / 简单状态 | atomic |
| 协调多个 goroutine 的执行顺序 | channel + sync.WaitGroup |

> "Don't communicate by sharing memory; share memory by communicating." — 但这是建议不是教条。锁有时更简单。

### channel 红线

- ❌ 禁止向已关闭的 channel 发送（panic）
- ❌ 禁止重复关闭 channel（panic）
- ❌ 禁止从 nil channel 收发（永久阻塞）
- ✅ **谁创建谁关闭**，由 sender 关闭，receiver 不关闭
- ✅ 多个 sender 用 `sync.Once` 或独立的 done channel 协调关闭
- ✅ buffered channel 大小要有依据，不要随手写 `make(chan T, 100)`

### 方向限定

```go
// ✅ 函数签名指定 channel 方向
func produce(out chan<- int) {
    for i := 0; i < 10; i++ {
        out <- i
    }
    close(out)
}

func consume(in <-chan int) {
    for v := range in {
        fmt.Println(v)
    }
}
```

### select 默认分支陷阱

```go
// ❌ 反例：default 让 select 变成忙等
for {
    select {
    case <-ch:
        // ...
    default:
        // CPU 100%
    }
}

// ✅ 没有 default，阻塞等待
for {
    select {
    case v := <-ch:
        process(v)
    case <-ctx.Done():
        return
    }
}
```

## 自查

- [ ] goroutine 有 recover + 退出条件
- [ ] 锁粒度小，无持锁调用外部函数
- [ ] context 是第一个参数，下游尊重取消
- [ ] 无 `context.Background()` 在业务代码中
- [ ] channel 由 sender 关闭，方向限定
- [ ] 测试启用 `-race`
