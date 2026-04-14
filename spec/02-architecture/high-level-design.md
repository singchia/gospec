# 02.3 - 概要设计（HLD）与新服务 Checklist

> **适用**：设计新模块 / 新服务、写概要设计文档、走新服务上线前的设计完整性检查。

## 何时写 HLD

- 新服务上线
- 新模块（跨多个包）
- 跨多个 domain 的功能（详见 `monorepo.md` 的 domain 边界）
- 复杂的重构（如果同时需要 RFC，HLD 在 RFC 之后写）

## 编号与归档

- **编号**：`HLD-<三位序号>-<简述>` 如 `HLD-001-billing-system`
- **路径**：`docs/design/HLD-XXX-<简述>.md`
- **模板**：`docs/templates/high-level-design-template.md`

## HLD 与其他文档的关系

```
PRD（为什么做） ─┐
                 ├─→ HLD（系统怎么搭）─→ ADR（关键决策）─→ 代码实现
RFC（技术方案） ─┘
```

- HLD 总是关联到 PRD（业务需求）或 RFC（技术变更）
- HLD 中的关键决策点单独写 ADR
- HLD 不写 LLD（详细设计），LLD 体现在代码和注释里

## 状态流转

```
草稿 → 评审中 → 已批准
```

详细评审纪律对齐 `01-requirement/lifecycle.md`。

---

## 新服务上线 Checklist

新建一个对外服务前，必须完成以下设计产物（不只是写代码）：

### 设计阶段
- [ ] PRD（`01-requirement/product-requirement.md`）
- [ ] HLD（本文件 + `docs/templates/high-level-design-template.md`）
- [ ] ADR（涉及关键技术决策时，`architecture-decision-record.md`）
- [ ] 在 monorepo 中确定 domain 归属（`monorepo.md`）

### 接口与数据
- [ ] API 设计（`03-api/proto.md` + `03-api/http.md`，proto 优先）
- [ ] 数据存储选型（`04-data-model/README.md`）
- [ ] 数据模型（`04-data-model/<store>.md`）
- [ ] 数据保留策略（`13-database-migration/data-governance.md`）

### 安全
- [ ] 威胁建模（`11-security/threat-model.md`）
- [ ] 认证授权方案（`11-security/auth.md`）
- [ ] PII 处理评估（`11-security/privacy-audit.md`）

### 可观测性
- [ ] SLO 定义（`10-observability/slo-alerting.md`）
- [ ] 监控埋点方案（`10-observability/metrics.md` + `tracing.md`）
- [ ] 日志规范（`10-observability/logging.md`）
- [ ] 告警规则 + Runbook（`12-operations/incident.md`）

### 运维
- [ ] 部署策略 + 回滚方案（`12-operations/deployment.md`）
- [ ] 容量评估（`12-operations/capacity.md`）
- [ ] 备份策略（如有数据，`12-operations/backup-dr.md`）
- [ ] CI/CD pipeline（`08-delivery/cicd.md`）
- [ ] CODEOWNERS 已配置（`monorepo.md`）

## 自查

- [ ] HLD 已关联 PRD / RFC
- [ ] 系统架构图清晰
- [ ] 模块划分与职责明确
- [ ] 关键数据流已画出
- [ ] 关键技术决策已抽出为独立 ADR
- [ ] 上线前完成上述全部 checklist
