# 06.2 - 集成测试与 E2E

> **适用**：写带真实依赖（DB / Redis / MQ）的测试、写 E2E 流程、用 testcontainers。

## 集成测试

集成测试覆盖**多组件协作**：handler + service + dao + 真实 DB。

```go
//go:build integration

package edge_test

func TestEdge_CreateAndGet(t *testing.T) {
    dao := setupTestDAO(t) // 连测试 DB
    svc := NewEdgeService(dao)

    edge, err := svc.CreateEdge(ctx, &v1.CreateEdgeRequest{Name: "test"})
    require.NoError(t, err)

    got, err := svc.GetEdge(ctx, edge.ID)
    require.NoError(t, err)
    assert.Equal(t, "test", got.Name)
}
```

运行：

```bash
go test ./... -tags=integration -race
```

---

## testcontainers-go

集成测试推荐 `testcontainers-go`，每次跑都拉一个干净的 MySQL/Redis，不依赖宿主环境：

```go
import (
    "github.com/testcontainers/testcontainers-go/modules/mysql"
    "github.com/testcontainers/testcontainers-go/modules/redis"
)

func setupMySQL(t *testing.T) string {
    ctx := context.Background()
    container, err := mysql.Run(ctx, "mysql:8.0",
        mysql.WithDatabase("test"),
        mysql.WithUsername("root"),
        mysql.WithPassword("pass"),
    )
    require.NoError(t, err)
    t.Cleanup(func() { container.Terminate(ctx) })

    dsn, err := container.ConnectionString(ctx, "parseTime=true")
    require.NoError(t, err)
    return dsn
}

func setupRedis(t *testing.T) string {
    ctx := context.Background()
    container, err := redis.Run(ctx, "redis:7-alpine")
    require.NoError(t, err)
    t.Cleanup(func() { container.Terminate(ctx) })

    addr, _ := container.Endpoint(ctx, "")
    return addr
}
```

**好处：**
- CI 与本地一致
- 不需要预装服务
- 版本可控
- 测试间隔离

**注意：**
- 启动慢（首次拉镜像更慢），不要在每个 `*_test.go` 里都 `Run`，用 `TestMain` 共享
- CI 中需要 Docker 运行时

```go
// ✅ TestMain 共享容器
var sharedDSN string

func TestMain(m *testing.M) {
    ctx := context.Background()
    container, _ := mysql.Run(ctx, "mysql:8.0", ...)
    sharedDSN, _ = container.ConnectionString(ctx, "parseTime=true")
    code := m.Run()
    container.Terminate(ctx)
    os.Exit(code)
}
```

---

## E2E 测试

E2E 测试连真实部署的服务，验证完整业务流程。

```go
//go:build e2e

package e2e

func TestEdgeLifecycle(t *testing.T) {
    client := newAPIClient(t, os.Getenv("E2E_BASE_URL"))

    // 1. 登录
    token := client.Login("test@example.com", "password")

    // 2. 创建 edge
    edge := client.CreateEdge(token, "test-edge")
    t.Cleanup(func() { client.DeleteEdge(token, edge.ID) })

    // 3. 获取 edge
    got := client.GetEdge(token, edge.ID)
    assert.Equal(t, "test-edge", got.Name)

    // 4. 删除（cleanup 自动执行）
}
```

运行：

```bash
go test ./test/e2e/ -tags=e2e -v
```

**E2E 红线：**
- 必须有清理函数（`t.Cleanup`），测试结束恢复环境
- 禁止依赖固定 ID（用动态创建）
- 禁止破坏性操作（删数据库、清空表）
- 跑在独立环境（dev / staging），**禁止跑在生产**
- 失败要能给出复现步骤（保留请求/响应日志）

---

## 测试数据管理

- **单元测试**：内存 mock 数据，无外部依赖
- **集成测试**：testcontainers 拉干净 DB，每个 test 用 `t.Cleanup` 清理
- **E2E 测试**：动态创建，测试后清理

**禁止：**
- ❌ 生产数据库连接字符串进入测试代码
- ❌ 测试之间共享可变状态
- ❌ 使用生产数据明文（脱敏方案见 `11-security/privacy-audit.md`）

## Race Detection

所有测试**必须**在竞态检测模式下运行：

```bash
go test ./... -race
```

CI 中强制启用 `-race`（详见 `08-delivery/cicd.md`），失败则阻断合并。

`-race` 会让测试慢 5-10x、内存高 5-10x，但能发现 99% 的并发 bug，必须开。

## 自查

- [ ] 集成测试用 testcontainers，不依赖宿主环境
- [ ] `TestMain` 共享重型 setup
- [ ] E2E 有清理函数 + 独立环境
- [ ] 无生产数据明文
- [ ] CI 启用 `-race`
