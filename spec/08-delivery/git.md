# 08.1 - Git 提交、分支、工作流

> 适用：写 commit message、起新分支、按工作流推进任务、本地起服务。

## Conventional Commits

```
<type>(<scope>): <description>

[可选 body]

[可选 footer]
```

### Type

| Type | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `refactor` | 重构（不改变功能） |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `docs` | 文档变更 |
| `style` | 代码格式（不影响逻辑） |
| `chore` | 构建/工具/依赖变更 |
| `ci` | CI/CD 配置变更 |
| `build` | 构建系统变更（Makefile、Dockerfile） |

### Scope

每个 Bounded Context 一个 scope（如 `user`、`order`、`billing`），外加通用 scope：`api`（proto/API 变更）、`data`（数据层）、`config`、`deps`、`ci`、`deploy`、`ops`。

### 示例

```
feat(user): 添加邮箱验证码注册功能
fix(data): 修复并发事务 race condition
refactor(order): 将订单查询逻辑提取到独立 usecase
test(user): 添加登录频率限制单元测试
chore(deps): 升级 go-kratos/kratos 至 v2.7.2
perf(data): 为 orders 表 user_id 字段添加索引
ci: 添加 Go 1.24 构建矩阵
docs(api): 更新 Swagger 接口文档
build(docker): 优化 order-api Dockerfile 多阶段构建
```

### 提交规则

1. **原子提交**：每个 commit 只做一件事
2. **完整可构建**：每个 commit 必须通过 `go build ./...` + `go test ./...`
3. **禁止提交敏感信息**（详见 `11-security/secrets-supply-chain.md`）
4. **禁止 force push main/master**

---

## 分支命名

| 场景 | 格式 | 示例 |
|------|------|------|
| 新功能 | `feature/<scope>-<desc>` | `feature/user-email-verification` |
| Bug 修复 | `fix/<scope>-<desc>` | `fix/data-concurrent-transaction` |
| 紧急修复 | `hotfix/<desc>` | `hotfix/login-panic` |
| 重构 | `refactor/<desc>` | `refactor/order-biz-split` |
| 文档 | `docs/<desc>` | `docs/api-swagger` |
| 依赖/工具 | `chore/<desc>` | `chore/upgrade-kratos` |

---

## 开发工作流

### 功能开发

```
需求确认 → 创建分支 → [写 ADR] → 更新 proto → 编码 → 测试 → 自查 → PR → CI → Review → 合并
```

1. 确认 PRD 或 issue 状态为「已确认」（`01-requirement/`）
2. 从 `main` 创建 `feature/<scope>-<desc>` 分支
3. 涉及架构变更，先写 ADR（`02-architecture/architecture-decision-record.md`）
4. **如有 API 变更**：先更新 `.proto`，再生成代码（`03-api/proto.md`）
5. 编码实现（`05-coding/`）
6. 编写测试（`06-testing/`）
7. 本地验证：
   ```bash
   go build ./...
   go test ./... -race
   go vet ./...
   ```
8. 对照 `07-code-review.md` 自查
9. 提交 PR，CI 自动运行（`cicd.md`）
10. Code Review 通过后合并

### Bug 修复

```
复现 → 创建分支 → 写失败测试 → 修复 → 回归 → PR → 合并
```

1. 复现问题，记录复现步骤
2. 从 `main` 创建 `fix/<scope>-<desc>` 分支
3. **先写一个能复现 bug 的失败测试用例**
4. 修复代码使测试通过
5. 运行全量测试：`go test ./... -race`
6. 提交 PR → 合并

### 发版

详见 `release.md`。

---

## .gitignore

```
# 二进制产物
bin/
dist/

# 环境变量
.env
.env.local
deploy/**/.env

# Go 构建缓存
.cache/

# IDE
.idea/
.vscode/

# 操作系统
.DS_Store
```

---

## 本地开发环境

```bash
# 启动依赖服务（具体服务按项目实际依赖调整）
cd deploy && docker-compose up -d

# 复制环境配置
cp deploy/.env.example deploy/.env

# 运行服务
go run ./cmd/order-api

# 常用命令
go build ./...
go test ./... -race -timeout 120s
go vet ./...
swag init -g cmd/order-api/main.go -o docs/swagger/
```

## 自查

- [ ] commit 格式符合 Conventional Commits
- [ ] 分支命名符合规范
- [ ] 每个 commit 独立可构建
- [ ] 未提交敏感信息（详见 `11-security/secrets-supply-chain.md`）
- [ ] 本地 `go build` / `go test -race` / `go vet` 全通过
