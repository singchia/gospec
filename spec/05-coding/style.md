# 05.5 - Style：import、注释、struct

> **适用**：组织 import、写注释、设计 struct 字段、决定结构体公开/私有。

## Import 排序

```go
import (
    // 1. 标准库
    "context"
    "errors"
    "fmt"
    "sync"
    "time"

    // 2. 第三方库（空行分隔）
    kratoserrors "github.com/go-kratos/kratos/v2/errors"
    "gorm.io/gorm"

    // 3. 项目内部包（空行分隔）
    v1 "github.com/singchia/liaison-cloud/api/v1"
    "github.com/singchia/liaison-cloud/pkg/liaison/config"
    "github.com/singchia/liaison-cloud/pkg/liaison/repo/model"
)
```

**规则：**
- 三段式分组，组间空行
- `goimports` 自动排序（CI 强制，详见 `08-delivery/cicd.md`）
- 别名只在冲突或简化长名时用：`v1 "..."`、`kratoserrors "..."`
- 禁止 `.` 导入（除测试 DSL）
- 禁止 `_` 导入做副作用（除驱动注册等明确场景）

---

## 注释

### 公开 API 必须有注释

```go
// ✅ 公开函数：从函数名开始
// NewLiaison 初始化 Liaison 服务，读取配置、初始化各组件并返回服务实例。
// 如果返回 ErrInvalidUsage，调用方不应记录错误（属于正常退出场景）。
func NewLiaison() (*Liaison, error) { ... }

// ✅ 公开类型
// Repo 聚合所有数据访问方法，业务层只依赖此接口。
type Repo interface { ... }
```

**规则：**
- 包级公开标识符（func / type / var / const）必须有 doc 注释
- 注释以**标识符名**开头，遵循 `golint` 约定
- 描述**意图**和**契约**，不描述实现
- 注明特殊行为：何时返回什么错误、是否 goroutine 安全、是否阻塞

### 行内注释只在 WHY 不明显时写

```go
// ✅ 解释 WHY
// 优先检查 X-Forwarded-For 头（用于反向代理场景）
forwarded := httpReq.Header.Get("X-Forwarded-For")

// ✅ 标注非显然的不变式
// invariant: lock 必须在 m.mu 已持有时调用
func (m *Manager) lockedUpdate(...) {

// ❌ 描述 WHAT，等于啰嗦
i := 0 // 初始化 i 为 0
```

### 注释禁忌

- ❌ 不要写"用于 XX 流程"（业务流程会变，注释会过期）
- ❌ 不要写"修改人 / 修改日期"（git blame 是真理）
- ❌ 不要写 TODO 而不留 issue 链接：`// TODO(alice): #123 重构这里`
- ❌ 不要把 commit message 复制成注释

---

## Struct 设计

### 字段顺序

```go
// ✅ 推荐顺序：依赖 → 配置 → 状态 → 锁
type IAMService struct {
    // 依赖
    repo    Repo
    casdoor *casdoorClient

    // 配置
    conf *config.Configuration

    // 内部状态
    codes map[string]emailCodeRecord

    // 同步原语放最后
    codeMu sync.Mutex
}
```

### 字段对齐与内存布局

```go
// ❌ 字段顺序不当导致 padding 浪费
type Bad struct {
    a bool   // 1 byte + 7 padding
    b int64  // 8 byte
    c bool   // 1 byte + 7 padding
} // 24 bytes

// ✅ 大字段在前，小字段聚拢
type Good struct {
    b int64  // 8 byte
    a bool   // 1 byte
    c bool   // 1 byte + 6 padding
} // 16 bytes
```

热点结构体（高频创建）才需要关注。普通业务对象按可读性排序即可。

### 公开 vs 私有

```go
// ✅ 私有字段 + 通过接口暴露
type iamService struct {
    repo Repo
}

func NewIAMService(repo Repo) IAMService {
    return &iamService{repo: repo}
}
```

**规则：**
- 默认私有，按需公开
- 公开字段意味着调用方可以直接读写，破坏不变式
- 公开字段的 struct 通常用于：DTO、配置对象、纯数据载体

### 单一职责

- 单一职责，字段不超过 10 个
- 超过 10 个考虑拆分或嵌入子结构体

```go
// ❌ 上帝结构体
type User struct {
    ID, Name, Email, Phone, Address1, Address2, City, State, Zip, Country, ...  // 30 个字段
}

// ✅ 拆分
type User struct {
    ID      int64
    Name    string
    Email   string
    Phone   string
    Address Address  // 嵌入
}

type Address struct {
    Line1   string
    Line2   string
    City    string
    State   string
    Zip     string
    Country string
}
```

### 零值可用

```go
// ✅ 零值可用，无需 New*
var buf bytes.Buffer
buf.WriteString("hello") // 直接用

var mu sync.Mutex
mu.Lock()                // 直接用

// ✅ 自己的类型也尽量零值可用
type Counter struct {
    mu sync.Mutex
    n  int64
}

func (c *Counter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.n++
}

// var c Counter; c.Inc() 直接能用
```

**何时不能零值可用**：依赖外部资源（DB 连接、配置、密钥），必须通过构造函数。

### 嵌入（Embedding）

```go
// ✅ 嵌入用于"is-a"组合
type ReadWriter struct {
    io.Reader
    io.Writer
}

// ❌ 不要用嵌入模拟继承
type BaseService struct {
    logger *slog.Logger
}
type UserService struct {
    BaseService  // 反例：不要这样组织业务代码
}

// ✅ 显式字段更清晰
type UserService struct {
    logger *slog.Logger
}
```

**规则**：嵌入只用于真正的接口组合（如 `io.ReadWriter`）或对外暴露第三方类型的方法集，**不要用于业务代码的代码复用**。

---

## 文件组织

- 一个文件聚焦一个主题
- 文件名 snake_case：`dao_user.go`、`model_edge.go`、`controller_login.go`
- 测试文件与被测文件并列：`dao_user_test.go`
- 单文件不超过 500 行，超过考虑拆分

## 自查

- [ ] import 三段式分组，goimports 自动排序
- [ ] 公开 API 有以名字开头的 doc 注释
- [ ] 注释解释 WHY 不解释 WHAT
- [ ] struct 字段按 依赖→配置→状态→锁 排序
- [ ] 默认私有，按需公开
- [ ] 字段数 < 10，超过考虑拆分
- [ ] 零值可用（除非依赖外部资源）
- [ ] 嵌入只用于接口组合，不模拟继承
- [ ] 单文件 < 500 行
