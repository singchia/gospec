# 05.4 - 设计模式

> **适用**：构造对象、组合行为、并发编排、容错重试、领域分层。
>
> 这些是**Go 项目里真的用得上**的模式（而非《设计模式》里照搬过来的 GoF）。每个模式给出意图、何时用、Go 实现、何时**不要**用。

## 模式索引

| 类别 | 模式 | 何时用 |
|------|------|--------|
| 构造 | Functional Options | 构造函数有 5+ 可选配置 |
| 构造 | Constructor Injection | 任何有依赖的服务（无 init / 无全局） |
| 行为 | Strategy | 同一接口多实现，运行时切换 |
| 行为 | Decorator / Middleware | 横切关注点（日志、metrics、auth、retry） |
| 行为 | Adapter | 适配第三方接口 / 老接口 |
| 并发 | Worker Pool | 限制并发数处理批量任务 |
| 并发 | Pipeline | 多阶段流式处理 |
| 并发 | Errgroup | 一组并发任务，任一失败全部取消 |
| 容错 | Retry with Backoff | 临时故障的可重试调用 |
| 容错 | Circuit Breaker | 防止雪崩（详见 `11-security/input-crypto.md`） |
| 领域 | Repository | 数据访问抽象（已在架构中强制） |
| 一致性 | Outbox | 跨服务最终一致 |

---

## 1. Functional Options

### 意图

构造函数有多个可选配置时，避免参数爆炸或多个 `New*` 重载。

### 何时用

- 构造函数有 5+ 配置项
- 配置项中大多数有默认值
- 未来可能新增配置项

### 实现

```go
type Server struct {
    addr        string
    timeout     time.Duration
    maxConns    int
    tlsConfig   *tls.Config
    logger      *slog.Logger
}

type Option func(*Server)

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func WithMaxConns(n int) Option {
    return func(s *Server) { s.maxConns = n }
}

func WithTLS(cfg *tls.Config) Option {
    return func(s *Server) { s.tlsConfig = cfg }
}

func WithLogger(l *slog.Logger) Option {
    return func(s *Server) { s.logger = l }
}

func NewServer(addr string, opts ...Option) *Server {
    s := &Server{
        addr:     addr,
        timeout:  30 * time.Second, // 默认值
        maxConns: 100,
        logger:   slog.Default(),
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}

// 调用方
srv := NewServer(":8080",
    WithTimeout(60*time.Second),
    WithMaxConns(500),
    WithTLS(tlsCfg),
)
```

### 何时**不**用

- 构造函数只有 1-3 个参数（直接传参更清晰）
- 所有参数都是必填的（用普通构造函数 + 校验）

---

## 2. Constructor Injection（依赖注入）

### 意图

依赖通过构造函数显式传入，禁止全局变量、init、单例。

### 实现

```go
// ✅ 依赖通过构造函数注入
type EdgeService struct {
    repo   Repo        // 接口
    cache  Cache       // 接口
    clock  Clock       // 接口（便于测试）
    logger *slog.Logger
}

func NewEdgeService(repo Repo, cache Cache, clock Clock, logger *slog.Logger) *EdgeService {
    return &EdgeService{
        repo:   repo,
        cache:  cache,
        clock:  clock,
        logger: logger,
    }
}

// main 中组装
func main() {
    db := newDB()
    repo := dao.NewRepo(db)
    cache := redis.NewCache()
    svc := iam.NewEdgeService(repo, cache, realClock{}, slog.Default())
    // ...
}
```

### 关键点

- **接口在消费方定义**，不在实现方
- 测试时注入 mock，不需要任何 mock 框架
- 不需要 wire / fx 等 DI 框架（可选，团队约定）

### 反模式

```go
// ❌ 全局变量
var DefaultRepo Repo
func init() { DefaultRepo = newRepo() }

// ❌ 单例
var instance *Service
func GetService() *Service {
    if instance == nil { instance = &Service{} }
    return instance
}

// ❌ 隐式依赖（在函数内部 new）
func (s *Service) Do() {
    repo := dao.NewRepo() // 不可测、不可换
}
```

---

## 3. Strategy（策略）

### 意图

同一行为有多种实现，运行时根据条件选择。

### 实现

```go
// ✅ 接口定义策略
type PaymentMethod interface {
    Charge(ctx context.Context, amount Money) error
}

type alipay struct{ client *alipay.Client }
func (a *alipay) Charge(ctx context.Context, amount Money) error { ... }

type wechat struct{ client *wechat.Client }
func (w *wechat) Charge(ctx context.Context, amount Money) error { ... }

type stripe struct{ client *stripe.Client }
func (s *stripe) Charge(ctx context.Context, amount Money) error { ... }

// 注册表
type PaymentRegistry struct {
    methods map[string]PaymentMethod
}

func (r *PaymentRegistry) Pay(ctx context.Context, method string, amount Money) error {
    m, ok := r.methods[method]
    if !ok {
        return fmt.Errorf("unknown payment method: %s", method)
    }
    return m.Charge(ctx, amount)
}
```

### 何时用

- 行为有多种"插件"实现
- 新增实现不应改老代码

### 反模式

```go
// ❌ 用 if/switch 而非接口
func Pay(method string, amount Money) error {
    switch method {
    case "alipay":
        return chargeAlipay(amount)
    case "wechat":
        return chargeWechat(amount)
    // ... 加新方式时要改这里
    }
}
```

---

## 4. Decorator / Middleware

### 意图

把横切关注点（日志、metrics、auth、retry、cache）从核心逻辑剥离，通过装饰器叠加。

### 实现：装饰接口

```go
type Repo interface {
    GetUser(ctx context.Context, id int64) (*User, error)
}

// 核心实现
type repo struct{ db *sql.DB }
func (r *repo) GetUser(ctx context.Context, id int64) (*User, error) { ... }

// 日志装饰器
type loggingRepo struct {
    inner  Repo
    logger *slog.Logger
}

func (l *loggingRepo) GetUser(ctx context.Context, id int64) (*User, error) {
    start := time.Now()
    user, err := l.inner.GetUser(ctx, id)
    l.logger.InfoContext(ctx, "GetUser",
        slog.Int64("id", id),
        slog.Duration("cost", time.Since(start)),
        slog.Any("err", err),
    )
    return user, err
}

// Metrics 装饰器
type metricsRepo struct {
    inner Repo
    hist  *prometheus.HistogramVec
}

func (m *metricsRepo) GetUser(ctx context.Context, id int64) (*User, error) {
    timer := prometheus.NewTimer(m.hist.WithLabelValues("GetUser"))
    defer timer.ObserveDuration()
    return m.inner.GetUser(ctx, id)
}

// 组装
func NewRepo(db *sql.DB, logger *slog.Logger, hist *prometheus.HistogramVec) Repo {
    var r Repo = &repo{db: db}
    r = &metricsRepo{inner: r, hist: hist}
    r = &loggingRepo{inner: r, logger: logger}
    return r
}
```

### 实现：HTTP middleware

```go
// ✅ 函数式 middleware
type Middleware func(http.Handler) http.Handler

func Logging(logger *slog.Logger) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()
            next.ServeHTTP(w, r)
            logger.InfoContext(r.Context(), "http",
                slog.String("method", r.Method),
                slog.String("path", r.URL.Path),
                slog.Duration("cost", time.Since(start)),
            )
        })
    }
}

// 链式组装
func Chain(h http.Handler, mws ...Middleware) http.Handler {
    for i := len(mws) - 1; i >= 0; i-- {
        h = mws[i](h)
    }
    return h
}

handler := Chain(coreHandler, Logging(logger), Metrics(), Auth(jwt))
```

### 何时用

- 多个实现都需要相同的横切行为
- 想保持核心逻辑干净

### 何时**不**用

- 只有一个实现：直接在核心代码里加日志即可
- 装饰器超过 3 层：考虑改 middleware 链或 AOP 思路

---

## 5. Adapter（适配器）

### 意图

把不兼容的接口转成期望的接口。

### 典型场景

- 适配第三方库（不同 SDK 但相同概念）
- 把老接口包装成新接口（重构期间共存）

### 实现

```go
// 我们期望的接口
type Cache interface {
    Get(ctx context.Context, key string) ([]byte, error)
    Set(ctx context.Context, key string, val []byte, ttl time.Duration) error
}

// 第三方 redis 库的接口长这样
// type RedisClient struct{}
// func (c *RedisClient) Do(cmd string, args ...interface{}) (interface{}, error)

// 适配器
type redisCache struct {
    client *redis.Client
}

func (r *redisCache) Get(ctx context.Context, key string) ([]byte, error) {
    return r.client.Get(ctx, key).Bytes()
}

func (r *redisCache) Set(ctx context.Context, key string, val []byte, ttl time.Duration) error {
    return r.client.Set(ctx, key, val, ttl).Err()
}

func NewRedisCache(client *redis.Client) Cache {
    return &redisCache{client: client}
}
```

### 价值

业务代码只依赖 `Cache` 接口，将来换 memcached / 内存缓存只改 adapter。

---

## 6. Worker Pool（工作池）

### 意图

固定数量的 worker 处理大量任务，限制并发数避免压垮下游。

### 实现

```go
type Pool struct {
    workers int
    tasks   chan func()
    wg      sync.WaitGroup
}

func NewPool(workers int) *Pool {
    p := &Pool{
        workers: workers,
        tasks:   make(chan func(), workers*2),
    }
    p.wg.Add(workers)
    for i := 0; i < workers; i++ {
        go p.worker()
    }
    return p
}

func (p *Pool) worker() {
    defer p.wg.Done()
    for task := range p.tasks {
        func() {
            defer func() {
                if r := recover(); r != nil {
                    slog.Error("pool worker panic", slog.Any("panic", r))
                }
            }()
            task()
        }()
    }
}

func (p *Pool) Submit(task func()) {
    p.tasks <- task
}

func (p *Pool) Close() {
    close(p.tasks)
    p.wg.Wait()
}
```

### 何时用

- 批量任务，每个独立
- 需要限制对下游的并发压力（DB / 第三方 API）
- 任务执行时间可预估

### 何时**不**用

- 任务量极少（直接 goroutine 即可）
- 需要严格的任务顺序（用 channel + 单 worker）
- 需要错误聚合 / 取消传播 → 用 errgroup

---

## 7. Pipeline（管道）

### 意图

多阶段流水线处理：每阶段一个 goroutine + channel 串联，天然并行。

### 实现

```go
// 阶段 1：生成 ID
func gen(ctx context.Context, ids ...int64) <-chan int64 {
    out := make(chan int64)
    go func() {
        defer close(out)
        for _, id := range ids {
            select {
            case <-ctx.Done():
                return
            case out <- id:
            }
        }
    }()
    return out
}

// 阶段 2：根据 ID 查 DB
func fetch(ctx context.Context, in <-chan int64, repo Repo) <-chan *User {
    out := make(chan *User)
    go func() {
        defer close(out)
        for id := range in {
            user, err := repo.GetUser(ctx, id)
            if err != nil { continue }
            select {
            case <-ctx.Done():
                return
            case out <- user:
            }
        }
    }()
    return out
}

// 阶段 3：处理结果
func process(ctx context.Context, in <-chan *User) <-chan Result {
    out := make(chan Result)
    go func() {
        defer close(out)
        for u := range in {
            out <- Process(u)
        }
    }()
    return out
}

// 组装
func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    ids := gen(ctx, 1, 2, 3, 4, 5)
    users := fetch(ctx, ids, repo)
    results := process(ctx, users)

    for r := range results {
        fmt.Println(r)
    }
}
```

### Fan-out / Fan-in

把单个阶段拆成 N 个并行 worker（fan-out），再合并结果（fan-in）：

```go
func fanOut(ctx context.Context, in <-chan int64, n int, repo Repo) <-chan *User {
    out := make(chan *User)
    var wg sync.WaitGroup
    wg.Add(n)
    for i := 0; i < n; i++ {
        go func() {
            defer wg.Done()
            for id := range in {
                user, err := repo.GetUser(ctx, id)
                if err == nil {
                    out <- user
                }
            }
        }()
    }
    go func() {
        wg.Wait()
        close(out)
    }()
    return out
}
```

---

## 8. Errgroup（一组任务，任一失败全取消）

### 意图

并发执行多个任务，任一失败立即取消其他任务，并返回第一个错误。

### 实现

```go
import "golang.org/x/sync/errgroup"

func (s *Service) FetchAll(ctx context.Context) (*Result, error) {
    g, ctx := errgroup.WithContext(ctx)

    var user *User
    var orders []*Order
    var quota *Quota

    g.Go(func() error {
        var err error
        user, err = s.userRepo.Get(ctx, userID)
        return err
    })

    g.Go(func() error {
        var err error
        orders, err = s.orderRepo.List(ctx, userID)
        return err
    })

    g.Go(func() error {
        var err error
        quota, err = s.quotaRepo.Get(ctx, userID)
        return err
    })

    if err := g.Wait(); err != nil {
        return nil, err
    }
    return &Result{User: user, Orders: orders, Quota: quota}, nil
}
```

### 限制并发数

`errgroup.SetLimit(n)`（Go 1.20+）：

```go
g, ctx := errgroup.WithContext(ctx)
g.SetLimit(10) // 最多 10 个并发

for _, item := range items {
    item := item
    g.Go(func() error {
        return process(ctx, item)
    })
}
return g.Wait()
```

**何时用 errgroup vs worker pool**：errgroup 用于"一次性"的并发任务集合；worker pool 用于"持续"的任务流。

---

## 9. Retry with Exponential Backoff

### 意图

对临时性故障（网络抖动、5xx）进行重试，但不打挂下游。

### 实现

```go
type RetryConfig struct {
    MaxAttempts int
    InitialWait time.Duration
    MaxWait     time.Duration
    Multiplier  float64
}

func Retry(ctx context.Context, cfg RetryConfig, fn func(ctx context.Context) error) error {
    wait := cfg.InitialWait
    var lastErr error
    for attempt := 1; attempt <= cfg.MaxAttempts; attempt++ {
        if err := fn(ctx); err == nil {
            return nil
        } else {
            lastErr = err
            if !isRetryable(err) {
                return err
            }
        }

        if attempt == cfg.MaxAttempts {
            break
        }

        // 加 jitter，避免惊群
        jitter := time.Duration(rand.Int63n(int64(wait) / 2))
        sleep := wait + jitter

        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-time.After(sleep):
        }

        wait = time.Duration(float64(wait) * cfg.Multiplier)
        if wait > cfg.MaxWait {
            wait = cfg.MaxWait
        }
    }
    return fmt.Errorf("after %d attempts: %w", cfg.MaxAttempts, lastErr)
}

func isRetryable(err error) bool {
    var netErr net.Error
    if errors.As(err, &netErr) && netErr.Timeout() {
        return true
    }
    // 5xx / Unavailable
    return false
}
```

### 红线

- ❌ 不可重试的错误（4xx、参数错误、业务校验失败）禁止重试
- ❌ 没 jitter 的 backoff 会导致惊群（thundering herd）
- ❌ 重试次数无上限
- ❌ 重试链路长度不可控（A 重试 B，B 重试 C，C 重试 D = 指数级请求）
- ✅ 必须配 timeout 或 deadline
- ✅ 推荐用成熟库：`cenkalti/backoff/v4`

### 何时配 Circuit Breaker

下游持续失败时，重试只会加重雪崩。重试 + 熔断要配合使用，详见 `11-security/input-crypto.md`。

---

## 10. Outbox（发件箱模式）

### 意图

跨服务最终一致性。业务写 DB 和发消息要么都成功要么都失败，但不能用分布式事务。

### 实现

```
1. 业务事务：
   BEGIN
     INSERT INTO orders (...)             -- 业务表
     INSERT INTO outbox (event_type, payload, status='pending')  -- 同事务写 outbox
   COMMIT

2. 后台 worker：
   SELECT * FROM outbox WHERE status='pending' ORDER BY id LIMIT 100
   for each event:
     publish to kafka / mq
     UPDATE outbox SET status='sent' WHERE id=?
```

### 关键点

- **业务表和 outbox 在同一个事务**：保证一致性
- **消费方必须幂等**：可能重复投递
- **outbox 表要清理**：详见 `13-database-migration/data-governance.md`

### 何时用

- 需要"业务成功 → 消息一定发出"
- 不接受用 2PC / XA 事务

### 替代方案

- **CDC（Change Data Capture）**：用 Debezium 监听 binlog，业务代码不感知
- **事务消息**：RocketMQ 提供半消息机制

---

## 反模式合集

### Singleton

```go
// ❌
var instance *Service
func GetService() *Service { ... }

// ✅ 用构造函数 + DI
func main() {
    svc := NewService(deps)
    handler := NewHandler(svc)
}
```

### 继承（Go 没有继承，别模仿 Java）

```go
// ❌ 想用嵌入模拟继承
type BaseService struct{}
func (b *BaseService) Common() {}

type UserService struct {
    BaseService
}

// ✅ 显式组合
type UserService struct {
    common *CommonOps  // 显式组合，不暴露
}
```

### 字符串类型化的 API

```go
// ❌
func CreateOrder(status string) // 调用方不知道有哪些值

// ✅ 用 enum 类型
type OrderStatus int
const (
    StatusPending OrderStatus = iota
    StatusPaid
    StatusShipped
)
func CreateOrder(status OrderStatus)
```

### 过早抽象

```go
// ❌ 一上来就定义接口，但只有一个实现
type UserService interface { ... }
type userServiceImpl struct{}

// ✅ 先用具体类型，需要时再抽象
type UserService struct{}
```

**经验法则**：**接口在消费方定义**。当某个调用方需要 mock 或多实现时，再在调用方定义所需的最小接口。

---

## 自查

- [ ] 构造函数有 5+ 配置 → Functional Options
- [ ] 服务依赖 → 构造函数注入，无全局 / init / 单例
- [ ] 多实现的行为 → 接口 + Strategy，不用 if/switch 大杂烩
- [ ] 横切关注点（日志/metrics/auth）→ Middleware / Decorator
- [ ] 并发任务集合 → errgroup（不是裸 goroutine + WaitGroup）
- [ ] 持续任务流 → Worker Pool
- [ ] 多阶段处理 → Pipeline + fan-out
- [ ] 临时故障 → Retry + 指数退避 + jitter，配熔断
- [ ] 跨服务一致性 → Outbox / CDC，不用 2PC
- [ ] 没有 Singleton / 继承模拟 / 字符串类型化 / 过早抽象
