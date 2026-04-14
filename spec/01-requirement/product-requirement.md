# 01.3 - PRD（产品需求文档）

> **适用**：用户可感知的功能 / 业务变更。
>
> PRD 描述"做什么 + 为什么 + 验收标准"，不描述"怎么做"。"怎么做"在 RFC / ADR / HLD / 代码里。

## 何时用 PRD

✅ **该写 PRD**：

- 新功能（用户能看到的）
- 对现有功能的行为变更
- UI / API 对外可见的变化
- 影响业务指标的变更

❌ **不该写 PRD**：

- 修 bug → issue
- 重构 / 性能优化（行为不变）→ RFC
- 配置 / 文档 → issue

## PRD 大小

- 单 PRD **2-4 周**可完成
- 太大 → 拆成 **Epic** + 多个独立 PRD（详见 `epic.md`）
- 太小（< 3 天）→ 合并到 issue
- **核心**：每个 PRD 必须能**独立上线** + **独立验证**

### 拆分维度

| 拆分原则 | ✅ 推荐 | ❌ 反例 |
|---------|--------|--------|
| 按**用户场景** | 注册 / 登录 / 找回密码 是 3 个 PRD | — |
| 按**技术模块** | — | DB 改动 / API 改动 / 前端改动 不应该是独立 PRD（同 PRD 的 task） |

## 编号与归档

- **编号**：`PRD-<三位序号>-<简述>` 如 `PRD-001-iam-email-verification`
- **路径**：`docs/requirements/PRD-XXX-<简述>.md`
- **模板**：[`docs/templates/product-requirement-template.md`](../../docs/templates/product-requirement-template.md)（创建新 PRD 时直接复制）

## 必填字段（模板已包含）

| 字段 | 必填 | 说明 |
|------|------|------|
| 元信息 | ✅ | 状态、作者、日期、关联 Epic / ADR / HLD |
| 背景 | ✅ | 为什么做、目标用户 |
| 目标 | ✅ | **可量化指标** |
| 功能需求 | ✅ | 核心功能 + 边界情况 |
| 非功能需求 | ✅ | 性能 / 安全 / 运维 / 兼容性 |
| API 变更 | 涉及时必填 | 跳转 `03-api/` |
| 数据库变更 | 涉及时必填 | 跳转 `04-data-model/` + `13-database-migration/migration.md` |
| 依赖与阻塞 | ✅ | 上下游识别 |
| 风险与假设 | ✅ | 已知风险 + 未验证假设 + 未知项 |
| 验收标准 | ✅ | 行为可观察、可验证 |
| 优先级 | ✅ | P0 / P1 / P2 / P3 |
| 排期 | ✅ | 开始 + 完成日期 |
| 任务拆分 | ✅ | 1-3 天颗粒度 |
| 变更记录 | 已确认后变更时填 | 详见 `lifecycle.md` |
| 上线后复盘 | ✅ | 上线 4 周内，详见 `lifecycle.md` |

## Task 拆分

PRD 内的 task：

- 单 task **1-3 天**可完成
- 单 task 可**独立测试**
- task 在 issue tracker 中跟踪（详见 `issue.md`）
- 完整 task 列表写在 PRD 正文里，便于全局查看

## 与设计文档联动

PRD 不替代设计文档。涉及以下情况时，**必须先有对应文档**再开发：

| PRD 涉及 | 必须先有 | 详见 |
|---------|---------|------|
| 引入新的重要外部依赖 | ADR | `02-architecture/architecture-decision-record.md` |
| 变更核心架构模式 | ADR + HLD | 同上 + `02-architecture/high-level-design.md` |
| 选择新技术方案 | ADR | 同上 |
| 跨多个 domain 的功能 | HLD | `02-architecture/high-level-design.md` |
| 新服务 / 新模块 | HLD + 新服务 Checklist | 同上 |

PRD 元信息中的"关联 ADR / HLD"必填关联编号。

## 流程

```
草稿 → 评审中 → 已确认 → 开发中 → 已完成 → 复盘中 → 已完成
```

详见 `lifecycle.md` 状态流转。

## 自查

- [ ] 用 PRD 是对的（不是 issue 也不是 RFC）
- [ ] 元信息完整（关联 Epic / ADR / HLD）
- [ ] 目标有可量化指标
- [ ] 功能需求覆盖主流程 + 边界情况
- [ ] 非功能需求已评估（性能 / 安全 / 运维 / 兼容性）
- [ ] API / DB 变更已描述
- [ ] 依赖和阻塞已识别
- [ ] 风险与假设已列出
- [ ] 验收标准可执行可验证
- [ ] 任务拆成 1-3 天颗粒度
- [ ] 涉及关键技术决策已关联 ADR
- [ ] 新模块 / 新服务已关联 HLD
- [ ] 单 PRD 大小 2-4 周
