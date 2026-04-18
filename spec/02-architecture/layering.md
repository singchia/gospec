# 02.1 - 单服务分层架构

> **适用**：设计单个服务的内部模块结构、决定接口归属、检查依赖方向。

## 分层架构（Kratos 风格命名，框架中性）

```
┌──────────────────────────────────────────┐
│  cmd/<service>/  （入口层）               │ ← 配置加载、DI 装配、信号处理
├──────────────────────────────────────────┤
│  server/         （Server 装配层）        │ ← HTTP/gRPC Server 构造、中间件链、路由注册
├──────────────────────────────────────────┤
│  service/        （Handler 层）          │ ← proto/HTTP 接口实现、参数校验、错误映射
├──────────────────────────────────────────┤
│  biz/            （业务层）               │ ← 业务用例 / 领域服务 / 事务边界
├──────────────────────────────────────────┤
│  data/           （数据访问层）           │ ← Repository / DAO / ORM / 缓存封装
├──────────────────────────────────────────┤
│  model/          （领域对象层）           │ ← 领域对象 / 持久化实体
└──────────────────────────────────────────┘
```

## 命名为什么用 Kratos 风格

这套命名和 Kratos 官方模板一致，但**不锁框架**——`server/` 层可以装配任何 HTTP 框架：

| 框架 | `server/` 里装什么 |
|------|------------------|
| Kratos v2 | `khttp.NewServer(...)` + `kgrpc.NewServer(...)` |
| gin | `gin.New()` + 注册 `service/` 的 handler |
| Hertz (CloudWeGo) | `hertz.New()` + handler |
| chi / echo / net/http | 各自的 router + handler |
| gRPC only | `grpc.NewServer()` + `pb.RegisterXxxServer(...)` |

**规范约束的是分层和依赖方向，不是框架选型。**

### 与其他风格的映射

同一套职责，不同社区有不同叫法。项目内**选一套坚持到底**：

| 职责 | Kratos 风格（**本规范推荐**） | Clean Arch 风格 | go-zero 风格 |
|------|---------------------------|---------------|------------|
| Handler | `service/` | `handler/` / `delivery/` | `logic/` |
| 业务用例 | `biz/` | `usecase/` | `svc/` |
| 数据访问 | `data/` | `repository/` | `model/` |
| 领域对象 | `biz/` 内或 `model/` | `entity/` | `model/` |

---

## 各层职责

### 入口层（`cmd/<service>/`）

- 只负责：配置加载、DI 装配、启动、信号处理、优雅退出
- 每个可部署服务一个目录：`cmd/order-api/` / `cmd/order-worker/` / `cmd/user-api/`
- **禁止业务逻辑**

```go
// cmd/order-api/main.go
func main() {
    cfg, err := conf.Load(*flagConf)
    if err != nil { log.Fatal(err) }

    app, cleanup, err := wireApp(cfg)   // DI 装配（wire / 手写构造器均可）
    if err != nil { log.Fatal(err) }
    defer cleanup()

    ctx, stop := signal.NotifyContext(context.Background(),
        syscall.SIGINT, syscall.SIGTERM)
    defer stop()

    if err := app.Run(ctx); err != nil {
        log.Fatal(err)
    }
}
```

### Server 装配层（`server/`）

- 构造 HTTP / gRPC Server 实例
- 装配中间件链：认证、限流、tracing、recover、日志
- 注册 `service/` 里的 handler 到 router / proto Server
- **不写业务参数校验**（那是 `service/` 的事）

### Handler 层（`service/`）

- 实现 proto 生成的 Server 接口，或挂到 HTTP 路由
- 从 context 解析认证用户
- 参数解析 + 调用 `biz/`
- 业务错误映射为 HTTP 状态码 / gRPC status（详见 `03-api/http.md`）
- **禁止直接访问 `data/` 层**

### 业务层（`biz/`）

- 核心业务逻辑 / 用例编排 / 事务边界
- 依赖 `data/` 的**接口**，不依赖具体实现
- 跨 BC 调用走 API / 事件，不直接 import 别的 BC

### 数据访问层（`data/`）

- 实现 `biz/` 定义的 Repo 接口
- GORM / sqlx / ent / redis / ClickHouse 等客户端的封装
- 详细规范见 `04-data-model/`

### 领域对象层（`model/`）

- 纯结构体，持久化实体 / 领域对象
- **不依赖任何上层**

---

## 依赖方向

```
cmd → server → service → biz → data → model
                 ↓
          internal/pkg/  （跨 BC 共享：auth / log / errs / trace）
```

**红线：**
- **单向依赖**：上层依赖下层，下层不依赖上层
- **禁止循环依赖**
- **禁止 `service` 直连 `data`**：必须经过 `biz`
- **`internal/pkg/`、`model/` 不依赖任何业务层**

```bash
# 检查循环依赖
go mod graph | grep cycle
# 或用 go-arch-lint 强制（见 monorepo.md）
```

---

## 接口设计原则

- **接口定义在消费方**，而非实现方
- **接口尽量小**：单一职责，参考 `io.Reader` 风格
- **公开接口，隐藏实现**：结构体首字母小写，通过接口暴露

```go
// ✅ 接口在消费方（biz）定义，data 层来实现
// internal/order/biz/order.go
type OrderRepo interface {
    Create(ctx context.Context, order *model.Order) (int64, error)
    GetByID(ctx context.Context, id int64) (*model.Order, error)
}

type OrderUsecase struct {
    repo OrderRepo
}

func NewOrderUsecase(repo OrderRepo) *OrderUsecase {
    return &OrderUsecase{repo: repo}
}
```

```go
// ✅ 实现首字母小写，构造函数返回接口
// internal/order/data/order.go
type orderRepo struct {
    db *gorm.DB
}

func NewOrderRepo(db *gorm.DB) biz.OrderRepo {
    return &orderRepo{db: db}
}
```

更多构造模式（Functional Options、DI、Decorator）见 `05-coding/patterns.md`。

## 自查

- [ ] 严格分层：`cmd → server → service → biz → data → model`
- [ ] 无跨层调用（`service` 不直接访问 `data`）
- [ ] 无循环依赖（`go mod graph` 验证）
- [ ] 接口在消费方（`biz`）定义，实现在 `data`
- [ ] 实现首字母小写，构造函数返回接口
- [ ] 依赖通过构造函数注入，无全局变量
- [ ] `cmd/` 不含业务逻辑，只做配置 + DI + 信号
