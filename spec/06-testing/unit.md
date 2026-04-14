# 06.1 - 单元测试

> **适用**：写单元测试、用 testify、做表格驱动测试、mock 依赖、写测试辅助函数。

## 基本范式（testify）

```go
import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestLoginProtection_Allow(t *testing.T) {
    guard := newLoginGuard()

    // require：前置条件失败立即停止
    require.NotNil(t, guard)

    // assert：收集所有失败后统一报告
    err := guard.Allow("127.0.0.1", "test@example.com", time.Now())
    assert.NoError(t, err)
}
```

**何时用 require / assert：**
- `require`：前置条件、setup 失败必须立即停止
- `assert`：业务断言，失败也要继续验证后续断言

---

## 表格驱动测试

```go
// ✅ 推荐：多输入场景统一管理
func TestNormalizeAvatarURL(t *testing.T) {
    cases := []struct {
        name  string
        input string
        want  string
    }{
        {"empty", "", ""},
        {"admin_path", "/admin/avatars/foo.png", "/dashboard/avatars/foo.png"},
        {"external_url", "https://example.com/avatar.png", "https://example.com/avatar.png"},
    }
    for _, tc := range cases {
        t.Run(tc.name, func(t *testing.T) {
            got := normalizeAvatarURL(tc.input)
            assert.Equal(t, tc.want, got)
        })
    }
}
```

**规则：**
- 每个 case 有 `name`，便于定位失败
- 用 `t.Run` 起子测试
- 边界 case 必须覆盖：空字符串、nil、零值、最大值

## 测试命名

```
Test<功能>_<场景>_<预期结果>
```

```
TestLogin_WhenRateLimited_Returns429
TestCreateEdge_WithDuplicateName_ReturnsError
TestGetUser_WhenNotFound_ReturnsErrNotFound
```

**核心**：测试名描述**行为**，不描述实现。"WhenRateLimited" 是行为，"WithMutexLocked" 是实现。

---

## Mock

```go
// ✅ 依赖接口便于 mock，测试时注入
type MockRepo struct {
    users map[int64]*model.User
}

func (m *MockRepo) GetUserByID(id int64) (*model.User, error) {
    if u, ok := m.users[id]; ok {
        return u, nil
    }
    return nil, gorm.ErrRecordNotFound
}

func TestIAMService_Login(t *testing.T) {
    svc := NewIAMService(testConf(), &MockRepo{
        users: map[int64]*model.User{1: {ID: 1, Email: "test@example.com"}},
    })
    // ...
}
```

**Mock 工具选项：**
- 手写 mock（少量、关系简单时推荐）
- `gomock`（接口数量多、需要严格期望时）
- `mockery`（基于接口自动生成）

**避免：**
- ❌ Mock 第三方库的内部行为（脆弱、不真实）
- ❌ Mock 自己不拥有的接口（DB driver 等）
- ❌ 过度 mock 导致测试只验证"调用了某方法"而非业务结果

---

## 测试辅助函数

```go
// ✅ 复用 setup 逻辑，用 t.Cleanup 自动清理
func setupTestDAO(t *testing.T) Dao {
    t.Helper()
    dao, err := NewDao(testConfig())
    require.NoError(t, err)
    t.Cleanup(func() { dao.Close() })
    return dao
}

func testConfig() *config.Configuration {
    return &config.Configuration{
        Manager: config.Manager{
            Database: config.Database{
                Driver: "mysql",
                DSN:    os.Getenv("TEST_DB_DSN"),
            },
        },
    }
}
```

**关键点：**
- `t.Helper()` 让失败堆栈指向调用方
- `t.Cleanup()` 自动清理，不依赖 defer
- helper 失败用 `require`，避免被测代码继续执行误导调试

## 自查

- [ ] 测试名描述行为而非实现
- [ ] 多输入用表格驱动，每 case 有 name
- [ ] 边界情况已覆盖（空、nil、零值、最大值）
- [ ] Mock 只 mock 自己拥有的接口
- [ ] 用 `t.Helper()` + `t.Cleanup()`
- [ ] 前置条件失败用 `require`
