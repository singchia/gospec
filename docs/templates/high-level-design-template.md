# HLD-XXX: <系统/模块名称>

> 完整规范见 `spec/02-architecture/high-level-design.md`（何时写、新服务上线 Checklist）。

- 状态：草稿 | 评审中 | 已批准
- 作者：
- 日期：YYYY-MM-DD
- 关联需求：PRD-XXX

## 系统架构图

```
┌──────────────┐     ┌──────────────┐
│  Component A │────▶│  Component B │
└──────────────┘     └──────────────┘
```

（使用 ASCII 或图片说明组件关系）

## 模块划分与职责

| 模块 | 包路径 | 职责 |
|------|--------|------|
| Server 装配 | `internal/<bc>/server/` | HTTP/gRPC Server 构造、中间件链、路由注册 |
| Handler | `internal/<bc>/service/` | proto/HTTP 接口实现、参数校验、错误映射 |
| 业务层 | `internal/<bc>/biz/` | 核心业务逻辑、用例编排、事务边界 |
| 数据层 | `internal/<bc>/data/` | 数据访问（DAO / ORM / 缓存封装） |
| 领域对象 | `internal/<bc>/model/` | 领域对象 / 持久化实体 |

## 核心数据流

```
请求 → 中间件（认证/tracing/限流） → Handler（service/） → Usecase（biz/） → Repo（data/） → MySQL
                                                               ↓
                                                      外部系统 / 依赖 BC（走 API / 事件）
```

## 关键接口定义

```go
// 新增/修改的核心接口
type NewService interface {
    DoSomething(ctx context.Context, req *Request) (*Response, error)
}
```

## 数据模型

```go
// 新增/修改的 GORM 模型
type NewEntity struct {
    ID        uint   `gorm:"primaryKey"`
    // ...
}
```

## 技术选型说明

- **选型 A**：选择理由（见 ADR-XXX）
- **选型 B**：选择理由

## 部署方案

- 服务依赖：MySQL、Redis、认证服务（Keycloak / Casdoor / Auth0 / 自研）、上下游 BC
- 端口：XXXX
- 配置项：`config.yaml` 中 `xxx.yyy` 字段

## 风险评估

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|---------|
| 数据库迁移失败 | 低 | 高 | 备份 + 回滚脚本 |
| 外部依赖不可用 | 中 | 中 | 超时+重试+熔断 |

## 测试策略

- 单元测试：mock 外部依赖，覆盖核心业务逻辑
- 集成测试：真实 DB，验证 DAO 操作
- E2E：完整流程验证
