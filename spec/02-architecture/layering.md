# 02.1 - 单服务分层架构

> **适用**：设计单个服务的内部模块结构、决定接口归属、检查依赖方向。

## 分层架构

```
┌─────────────────────────────────────┐
│         cmd/ （入口层）              │ ← 仅初始化和信号处理
├─────────────────────────────────────┤
│     manager/web/ （传输层）          │ ← HTTP handler，参数解析，错误映射
├─────────────────────────────────────┤
│  manager/controlplane/ （业务层）    │ ← 业务逻辑，用例编排
├─────────────────────────────────────┤
│       repo/ （数据访问层）           │ ← DAO 接口，GORM 实现，事务管理
├─────────────────────────────────────┤
│     repo/model/ （模型层）           │ ← GORM 结构体定义
└─────────────────────────────────────┘
```

## 各层职责

### 入口层（cmd/）

- 只负责初始化、启动、优雅退出
- 不包含任何业务逻辑

```go
// ✅ 推荐
func main() {
    svc, err := service.New()
    if err != nil {
        if err != lerrors.ErrInvalidUsage {
            log.Errorf("init err: %s", err)
        }
        return
    }
    go svc.Serve()
    sig := sigaction.NewSignal()
    sig.Wait(context.TODO())
    svc.Close()
}
```

### 传输层（manager/web/）

- 实现 proto 生成的 HTTP / gRPC Server 接口
- 从 context 解析认证用户信息
- 将领域错误映射为 HTTP 状态码（详见 `03-api/http.md`）
- **不包含业务逻辑**，只做参数转换和错误映射

### 业务层（manager/controlplane/）

- 实现核心业务逻辑和用例编排
- 协调多个 repo 操作，管理事务边界
- 依赖注入 repo 接口，不依赖具体实现

### 数据访问层（repo/）

- 聚合所有 DAO 方法到 Repo 接口
- 业务层只依赖 Repo 接口

详细规范见 `04-data-model/`。

---

## 模块依赖方向

```
cmd → service → web/controlplane/iam/billing/ops → repo → model
                                                  ↑
                                              lerrors/utils/proto
```

- **禁止循环依赖**
- **禁止 web 层直接访问 repo**（必须通过 controlplane）
- **utils/ 和 lerrors/ 不依赖任何业务包**

```bash
# 检查循环依赖
go mod graph | grep cycle
```

---

## 接口设计原则

- **接口定义在消费方**，而非实现方
- **接口尽量小**：单一职责，参考 `io.Reader` 风格
- **公开接口，隐藏实现**：结构体首字母小写，通过接口暴露

```go
// ✅ 推荐：接口在消费方定义
// pkg/liaison/manager/web/web.go
type ControlPlane interface {
    CreateEdge(ctx context.Context, req *v1.CreateEdgeRequest) (*v1.CreateEdgeResponse, error)
}

// ✅ 推荐：实现首字母小写，构造函数返回接口
type controlPlane struct { ... }

func NewControlPlane(...) (ControlPlane, error) {
    return &controlPlane{...}, nil
}
```

更多构造模式（Functional Options、DI、Decorator）见 `05-coding/patterns.md`。

## 自查

- [ ] 严格分层：cmd → web → controlplane → repo → model
- [ ] 无跨层调用（web 不直接访问 repo）
- [ ] 无循环依赖（`go mod graph` 验证）
- [ ] 接口在消费方定义
- [ ] 实现首字母小写，构造函数返回接口
- [ ] 依赖通过构造函数注入，无全局变量
