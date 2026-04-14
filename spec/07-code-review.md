# 07 - Code Review 自查清单

> **适用**：提交 PR 前的顶层 checklist。
>
> 具体细节在各专题 spec 里，本文件只列**可勾选项**和**对应详情位置**。某项不确定时再读对应 spec。

## 功能正确性

- [ ] 功能按需求（PRD 或 issue）正确实现
- [ ] 边界情况已处理（空字符串、nil、零值、超出范围的 ID）
- [ ] 错误路径全部覆盖并有对应测试
- [ ] 有对应的需求文档或 issue 关联

## 架构合规 → `02-architecture/`

- [ ] 单服务分层正确，无跨层调用（`02-architecture/layering.md`）
- [ ] 跨 domain 无直接 import，必须通过 API / 事件 / shared（`02-architecture/monorepo.md`）
- [ ] 接口定义在消费方，实现通过构造函数返回
- [ ] 无循环依赖（`go mod graph | grep cycle`）
- [ ] 新增 / 修改目录已被 CODEOWNERS 覆盖
- [ ] 新依赖经过评估，符合最小依赖原则

## 代码质量 → `05-coding/`

- [ ] 函数职责单一，不超过 80 行
- [ ] 命名符合规范（`05-coding/naming.md`）
- [ ] 无硬编码字符串、数字
- [ ] import 分组正确（`05-coding/style.md`）
- [ ] 公开函数有注释（`05-coding/style.md`）
- [ ] struct 字段顺序合理、单一职责（`05-coding/style.md`）

## 错误处理 → `05-coding/errors.md`

- [ ] 所有错误都被处理（无被忽略的返回值）
- [ ] 错误信息包含足够上下文（`%w` 包装）
- [ ] 错误不被重复记录
- [ ] HTTP 错误映射正确
- [ ] goroutine 内的 panic 有 recover

## 并发安全 → `05-coding/concurrency.md`

- [ ] 共享状态有锁保护
- [ ] context 正确传递并尊重取消信号
- [ ] goroutine 有退出条件（无泄漏）
- [ ] 持锁时不调用外部函数 / 第三方 API
- [ ] 测试启用了 `-race`

## 设计模式 → `05-coding/patterns.md`

- [ ] 构造函数有 5+ 配置 → Functional Options
- [ ] 服务依赖通过构造函数注入，无全局 / init / 单例
- [ ] 横切关注点（日志/metrics/auth）→ Middleware / Decorator
- [ ] 一组并发任务 → errgroup（不是裸 goroutine + WaitGroup）
- [ ] 临时故障 → Retry + 指数退避 + jitter，配熔断
- [ ] 跨服务一致性 → Outbox / CDC，不用 2PC

## API → `03-api/`

- [ ] Proto 是 API 变更的单一入口（`03-api/proto.md`）
- [ ] Handler 有完整 Swagger 注释（`03-api/middleware.md`）
- [ ] 认证路由白名单配置正确（`03-api/middleware.md`）
- [ ] 响应格式统一 code / message / data（`03-api/http.md`）
- [ ] 写操作接口幂等，破坏性变更走新版本（`03-api/versioning.md`）

## 数据层 → `04-data-model/`

- [ ] 数据存储选型合理（MySQL/Redis/CH/Influx 选对）→ `04-data-model/README.md`
- [ ] **MySQL**：事务正确（Commit/Rollback + panic recover），GORM struct tag 完整，列表有分页 → `04-data-model/mysql.md`
- [ ] **Redis**：所有 key 有 TTL，无大 key，多步操作用 Lua/事务 → `04-data-model/redis.md`
- [ ] **ClickHouse**：Replicated engine，批量写入，ORDER BY 合理 → `04-data-model/clickhouse.md`
- [ ] **InfluxDB**：tag 低基数，bucket 有 retention → `04-data-model/influxdb.md`

## 数据库变更 → `13-database-migration/migration.md`

- [ ] Schema 变更通过 migration 文件提交，有 down 脚本
- [ ] 兼容滚动发布（expand-contract）
- [ ] 大表变更已用在线 DDL 工具（`13-database-migration/online-ddl.md`）

## 安全 → `11-security/`

- [ ] 输入有白名单校验，SQL 全部参数化（`input-crypto.md`）
- [ ] 密码用 bcrypt/argon2id（`auth.md`）
- [ ] 多租户接口强制 `tenant_id` 过滤（`auth.md`）
- [ ] 敏感信息不写入日志，PII 字段加密存储（`privacy-audit.md`）
- [ ] 无密钥进入代码 / 镜像 / 日志（`secrets-supply-chain.md`）

## 可观测性 → `10-observability/`

- [ ] 关键路径有结构化日志，含 `trace_id`（`logging.md`）
- [ ] 对外服务有 RED 三件套指标（`metrics.md`）
- [ ] 出口调用有 tracing 覆盖（`tracing.md`）
- [ ] 新增依赖已加入 `/readyz`（`slo-alerting.md`）

## 测试 → `06-testing/`

- [ ] 新功能有对应单元测试（`06-testing/unit.md`）
- [ ] 测试覆盖率未下降（`06-testing/README.md`）
- [ ] 测试命名描述行为而非实现
- [ ] 多输入场景使用表格驱动测试
- [ ] E2E 场景有清理逻辑（`06-testing/integration.md`）
- [ ] 解析 / 协议代码有 fuzz 测试（`06-testing/fuzz-bench.md`）

## 性能

- [ ] 热点路径无不必要的内存分配
- [ ] 大数据量查询有 LIMIT / 分页限制
- [ ] 日志级别适当（DEBUG 不在生产默认开启）
- [ ] 数据库连接池配置合理

## 配置与部署 → `12-operations/deployment.md`

- [ ] 新配置项有默认值或必填校验
- [ ] Dockerfile / docker-compose 已同步更新
- [ ] 数据库迁移向后兼容
- [ ] `.env.example` 已同步更新
- [ ] 有明确的回滚步骤
- [ ] 高风险变更用了 feature flag 或金丝雀

## 文档 → `09-documentation.md`

- [ ] 涉及架构变更已写 ADR
- [ ] API 变更已更新 `.proto`，Swagger 已重新生成
- [ ] README / 部署文档已同步更新
