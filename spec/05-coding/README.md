# 05 - 编码

> 任何 Go 代码都要遵守。前置：架构（`02-architecture/`）、API（`03-api/`）、数据模型（`04-data-model/`）已设计完毕。

## 何时读哪个

| 当前任务 | 读这个 |
|---------|--------|
| 命名变量 / 函数 / 包 / 文件 | `naming.md` |
| 处理错误、设计 sentinel error、用 `%w` 包装 | `errors.md` |
| 写 goroutine、用锁、传 context、用 channel | `concurrency.md` |
| 设计构造函数、组合 / 装饰 / 适配 / 重试 / 并发模式 | `patterns.md` |
| import 顺序、写注释、设计 struct 字段、结构体生命周期 | `style.md` |

## 技术栈

| 领域 | 选型 |
|------|------|
| 语言 | Go 1.21+ |
| Web 框架 | go-kratos/kratos v2 |
| HTTP 路由 | gorilla/mux |
| ORM | gorm.io/gorm + gorm.io/driver/mysql |
| API 协议 | Protocol Buffers v3 + gRPC + HTTP/REST |
| 认证 | Casdoor + JWT (golang-jwt/jwt v5) |
| 配置 | gopkg.in/yaml.v2 |
| 日志 | `log/slog`（推荐，Go 1.21+）/ `zap`；存量项目兼容 `klog` |
| 指标 | prometheus/client_golang（详见 `10-observability/metrics.md`） |
| 追踪 | OpenTelemetry（详见 `10-observability/tracing.md`） |
| 测试 | testing + stretchr/testify |
| API 文档 | swaggo/swag |
| 进程管理 | armorigo/sigaction |
| 日志轮转 | gopkg.in/natefinch/lumberjack.v2 |
| 构建 | Go Modules + Makefile |
| 容器化 | Docker + docker-compose |
| CI/CD | GitHub Actions |

## 依赖引入原则

- 优先标准库：`net/http`、`context`、`sync`、`errors`、`fmt`、`time`
- 引入新依赖前评估是否可用标准库实现
- `go.mod` 锁定主版本，`go.sum` 提交到版本库
- 禁止 `replace` 指令进入主分支（除非本地调试临时使用，提交前必须移除）
- 依赖审查见 `11-security/secrets-supply-chain.md`

## 强制约束（不可违反）

- 禁止 `_ = fn()` 忽略错误（确实想丢弃必须注释说明）
- 共享状态必须加锁，测试必须带 `-race`
- 错误不重复记录：要么处理，要么向上传播
- 所有涉及 IO 的函数第一个参数为 `context.Context`
- `init()` 仅允许做注册（pprof / metrics collector / database driver 等纯静态注册），禁止做 IO 或可能 panic 的逻辑
- 禁止全局可变变量（配置通过依赖注入传递；Prometheus collector 等只读单例除外）
- 避免 `any` / `interface{}` 出现在公共 API 边界（解码 / SDK 适配 / 通用容器等不可避免场景必须就近注释说明并尽快用类型断言收敛）
- 禁止忽略 `Close()` 返回的错误
- 禁止 goroutine 中访问未加锁的共享状态
- 禁止硬编码字符串（URL、密钥、端口提取为配置项）
