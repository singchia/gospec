# 05.1 - 命名约定

> **适用**：给变量、函数、包、文件、接口、错误命名时。

## 命名表

| 类型 | 规则 | 示例 |
|------|------|------|
| 包名 | 小写单词，无下划线，简短 | `iam`、`controlplane`、`frontierbound` |
| 文件名 | 小写，下划线分隔 | `dao_user.go`、`model_edge.go` |
| 接口 | PascalCase，名词或形容词+er | `Repo`、`ControlPlane`、`Reader` |
| 结构体 | PascalCase（公开）/ camelCase（私有） | `IAMService`、`web`、`dao` |
| 函数 / 方法 | PascalCase（公开）/ camelCase（私有） | `NewLiaison`、`getDB` |
| 常量 | PascalCase 或 ALL_CAPS（仅全局配置常量） | `ErrInvalidUsage`、`MaxConnections` |
| 变量 | camelCase，语义清晰 | `loginIP`、`casdoorID`、`txDao` |
| 错误变量 | `Err` 前缀 | `ErrPortConflict`、`ErrInvalidUsage` |

## 包名规则

- 短、单数、小写：`user` 而非 `users`、`UserPackage`
- 与目录名一致
- 不要用通用词：`util`、`common`、`helper`、`misc`（无信息量）
- 内容相关：包名描述这个包做什么，不是它"是什么"

```go
// ✅ 包名隐含语义
package iam       // 身份认证
package edge      // edge 业务

// ❌
package utils     // 啥都装的杂货铺
package common    // 同上
```

## 接口命名

- 单方法接口用 `<动词>er`：`Reader`、`Writer`、`Closer`
- 多方法接口按职责命名：`Repo`、`Service`、`Cache`
- 接口名**不要带 `I` 前缀**（`IUserService` 是 Java 风格）

```go
// ✅
type EdgeRepo interface {
    Get(ctx context.Context, id int64) (*Edge, error)
    List(ctx context.Context, page, size int) ([]*Edge, error)
}

// ❌
type IEdgeRepo interface { ... }
```

## 函数命名

- 动词开头：`Create`、`Get`、`Update`、`Delete`、`List`
- Getter 不加 `Get` 前缀（Go 约定）：`u.Name()` 而非 `u.GetName()`
  - 但 proto 生成的 getter 是 `GetName()`，遵循生成代码即可
- Setter 加 `Set`：`u.SetName("alice")`
- 谓词函数返回 bool 用 `Is` / `Has` / `Can`：`IsActive()`、`HasPermission()`、`CanRead()`

## 变量命名

- 作用域越小，名字越短：循环变量 `i`、临时 `t`、局部 `cfg`；包级 / 公开变量必须详细
- 不要缩写无歧义的词：`user` 不要写 `usr`、`request` 不要写 `req`（除函数入参常用 `req`）
- 单位放后缀：`timeoutMs`、`sizeBytes`、`maxRetries`
- 布尔变量正向命名：`enabled` 而非 `disabled`、`hasError` 而非 `noError`

```go
// ✅
var maxRetries = 3
var timeoutMs = 5000
var enabled = true

// ❌
var max = 3              // 啥的 max？
var noTimeout = false    // 双重否定，难懂
```

## 错误命名

- 包级 sentinel 错误用 `Err` 前缀：`ErrNotFound`
- 类型化错误用 `XxxError` 后缀：`ValidationError`
- 错误信息小写开头、不带句号、不带换行（Go 标准）

```go
// ✅
var ErrNotFound = errors.New("not found")
return fmt.Errorf("create edge: %w", err)

// ❌
var ErrNotFound = errors.New("Not found.")  // 大写开头 + 句号
```

详见 `errors.md`。

## 自查

- [ ] 包名小写、单数、有信息量
- [ ] 接口无 `I` 前缀
- [ ] 函数动词开头，谓词用 Is/Has/Can
- [ ] 变量带单位后缀，布尔正向
- [ ] 错误小写开头无句号，sentinel 用 `Err` 前缀
