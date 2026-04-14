# 01 - 需求

> 任何编码工作开始前，先确认对应的需求载体存在且状态为「已确认」。

## 何时读哪个

| 当前任务 | 读这个 |
|---------|--------|
| 选载体（不知道该写 issue / RFC / PRD / Epic） | 本文件下方"载体分级"决策树 |
| 写 / 处理 issue、决定何时升级到 RFC / ADR | `issue.md` |
| 写技术 RFC（重构 / 依赖升级 / 性能优化） | `rfc.md` |
| 写产品 PRD（用户可感知的功能） | `prd.md` |
| 写 Epic（跨多个 PRD 的战略） | `epic.md` |
| 状态流转、变更追溯、质量检查、上线复盘 | `lifecycle.md` |

## 载体分级

不是所有变更都要写 PRD。按变更性质选对应的载体：

| 载体 | 适用 | 评审 | 存放位置 |
|------|------|------|---------|
| **Issue** | Bug、小改、配置调整、文档修复 | 1 人确认 | issue tracker（外部） |
| **RFC** | 纯技术变更（重构 / 依赖升级 / 性能优化） | 技术 1-2 人 | `docs/rfc/` |
| **PRD** | 用户可感知的功能 / 业务变更 | 产品 + 技术 | `docs/requirements/` |
| **Epic** | 跨多个 PRD 的战略方向 | 管理层 | `docs/requirements/` |

### 决策树

```
变更类型？
├─ 修 bug / 改配置 / 改文档 / 小工具脚本
│    → Issue
├─ 重构 / 升级依赖 / 性能优化 / 工具改造（用户不直接感知）
│    → RFC
├─ 用户能感知的新功能或行为变化
│    → PRD
└─ 跨多个团队、跨季度的方向
     → Epic（再拆 PRD）
```

**升级规则**：低层载体若发现规模超出，必须升级到高层载体重写，不要"在 issue 里写出一个 PRD"。

## Agent 行为约定

- 开始编码前，先检查是否有对应的 issue / RFC / PRD / Epic
- 若需求不存在或状态为「草稿 / 评审中」，向用户确认后再开始
- 若需求描述不清晰，**优先提问而非自行假设**
- 涉及关键技术决策的需求，必须先有 ADR（详见 `02-architecture/architecture-decision-record.md`）
- 涉及新模块 / 跨包功能，必须先有 HLD（详见 `02-architecture/high-level-design.md`）

## 共通原则（全局）

1. **载体匹配**：选对载体是第一步，不要用 issue 装 PRD，不要用 PRD 装 RFC
2. **状态门禁**：状态 ≠「已确认」之前不允许进入开发
3. **可量化目标**：所有载体都要有可验证的成功标准
4. **变更追溯**：已确认后禁止改正文，所有变更走 amendment（`lifecycle.md`）
5. **设计联动**：技术决策 → ADR；新模块 → HLD；不重复造文档
6. **闭环复盘**：上线后必须对照原目标做复盘（`lifecycle.md`）

## 文件命名汇总

| 类型 | 编号格式 | 路径 | 模板 |
|------|---------|------|------|
| Issue | tracker 自带 | issue tracker | — |
| RFC | `RFC-<三位序号>-<简述>` | `docs/rfc/RFC-XXX-*.md` | `docs/templates/technical-rfc-template.md` |
| PRD | `PRD-<三位序号>-<简述>` | `docs/requirements/PRD-XXX-*.md` | `docs/templates/product-requirement-template.md` |
| Epic | `EPIC-<三位序号>-<简述>` | `docs/requirements/EPIC-XXX-*.md` | — |
| ADR | `ADR-<三位序号>-<简述>` | `docs/adr/ADR-XXX-*.md` | `docs/templates/architecture-decision-record-template.md` |
| HLD | `HLD-<三位序号>-<简述>` | `docs/design/HLD-XXX-*.md` | `docs/templates/high-level-design-template.md` |
