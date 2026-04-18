# 06 - 测试

> 新功能必须有对应测试，CI 强制启用 `-race`，覆盖率不得低于目标值。

## 测试金字塔

```
        ┌─────────────┐
        │  E2E 测试   │  test/e2e/ — 真实服务、真实数据库、完整业务流程
        ├─────────────┤
        │  集成测试   │  *_test.go — 真实 DB 或 mock 外部依赖
        ├─────────────┤
        │  单元测试   │  *_test.go — mock 全部依赖，快速执行
        └─────────────┘
```

底层多、上层少。E2E 是补充验证，不是主力。

## 何时读哪个

| 当前任务 | 读这个 |
|---------|--------|
| 写单元测试、用 testify、表格驱动、mock、命名 | `unit.md` |
| 写集成测试、E2E、用 testcontainers、清理数据 | `integration.md` |
| 写 fuzz / benchmark / 跑 gosec/govulncheck | `fuzz-bench.md` |

## 覆盖率目标

| 层级 | 目标 | 优先级 |
|------|------|--------|
| 工具 / 纯函数（`internal/pkg/`） | 90%+ | P0 |
| 业务层（`biz/`） | 80%+ | P0 |
| 数据访问层（`data/`） | 70%+ | P1 |
| Handler 层（`service/`） | 60%+ | P2 |

```bash
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html
```

CI 覆盖率门禁详见 `08-delivery/cicd.md`。

## 文件组织

- 测试文件与被测文件**同包同目录**：`user_test.go` 与 `user.go` 并列
- E2E 测试放在 `test/e2e/`，使用独立 build tag
- 测试辅助函数放 `testutil_test.go` 或 `helpers_test.go`

## 强制约束（不可违反）

- 新功能必须有单元测试
- CI 强制启用 `-race`
- E2E 测试必须清理数据
- 禁止生产数据库连接字符串进入测试代码
- 禁止测试之间共享可变状态
- 禁止使用生产数据明文（脱敏方案见 `11-security/privacy-audit.md`）
