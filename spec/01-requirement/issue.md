# 01.1 - Issue

> **适用**：处理 bug、写小变更、改配置 / 文档；判断 issue 何时该升级到 RFC / PRD / ADR / Postmortem。

## Issue 的定位

issue 是**最轻量的需求载体**，承载：

- Bug 报告与修复
- 配置 / 文档 / 工具脚本的小改
- 用户反馈
- 技术债 / TODO 跟踪
- 任务跟踪（PRD 的 task 也用 issue 跟踪）

issue **不是** PRD 的替代品：用户可感知的功能即使"看起来很小"，也应该走 PRD。

## Tracker 选型

issue 存放在外部 issue tracker，**不进 docs/**。理由：

- 标签、看板、指派、通知、@提及、评论是 tracker 的核心能力，markdown 没有
- issue 高频 / 高量，进 git 会变成噪音
- 流程性内容（讨论）天然适合 tracker，沉淀性内容（结论）才进 docs/

**团队约定**：选定一个 tracker（GitHub Issues / Linear / Jira），全公司统一。

## 内容要求

### Bug Issue

```markdown
**环境**：服务名 / 版本 / 部署环境
**复现步骤**：
1. ...
2. ...

**期望行为**：
**实际行为**：
**日志 / trace_id**：
**截图 / 视频**（如适用）：
**严重程度**：P0 / P1 / P2 / P3
```

### 任务 Issue

```markdown
**关联**：PRD-XXX / RFC-XXX
**目标**：要做什么
**验收**：怎么算完成
**估时**：1-3 天颗粒度
```

## 双向链接（强制）

| 方向 | 实现方式 |
|------|---------|
| commit → issue | commit message 引用 `#123` |
| PR → issue | PR 描述写 `Closes #123` |
| issue → PR | tracker 自动反链 |
| issue → docs | 升级后在 issue 末尾留指针：`沉淀到 docs/adr/ADR-005-*.md` |

CI 中可以加 lint：合并的 PR 必须引用至少一个 issue。

## 升级规则（关键）

issue 是**讨论场所**，结论必须沉淀。当 issue 出现以下情况时，必须升级：

| issue 中出现 | 升级到 | 升级后 |
|-------------|-------|--------|
| 长讨论（> 10 条评论）+ 重要技术决策 | **ADR** | 写 ADR，issue 留指针，关闭 |
| 重构 / 依赖升级 / 性能优化方案讨论 | **RFC** | 写 RFC，issue 留指针，关闭 |
| 发现这其实是个用户可感知的新功能 | **PRD** | 写 PRD，issue 转为该 PRD 的 task |
| P0/P1 事故的根因讨论 | **Postmortem** | 写 postmortem（`12-operations/incident.md`），issue 关闭 |
| 涉及新模块 / 新服务 | **HLD + 新服务 Checklist** | 走 `02-architecture/high-level-design.md` 流程 |

### 升级原则

- **不要"把 issue 写成 PRD"**：发现规模超了，立即 stop，开新载体重写
- **沉淀完后 issue 关闭**：issue 正文最后一行加指针 `→ docs/adr/ADR-XXX.md`
- **沉淀文档反链 issue**：方便追溯讨论历史

## 标签规范（建议）

至少有以下 3 类标签：

| 类别 | 标签例 |
|------|-------|
| 类型 | `bug` / `feature` / `task` / `tech-debt` / `doc` |
| 严重度 | `P0` / `P1` / `P2` / `P3` |
| 状态 | `triaged` / `in-progress` / `blocked` / `needs-info` |

可选：`area:iam` / `area:billing`（按 monorepo domain，详见 `02-architecture/monorepo.md`）。

## issue 状态流转

```
新建 → triaged → in-progress → 关闭
        ↓             ↓
      blocked      needs-info
```

- **triaged**：已被 owner 确认（不是垃圾、不是重复、有效）
- **blocked**：等外部依赖，写明等什么
- **needs-info**：等用户补充信息

## 反模式

- ❌ issue 里写 PRD 内容（用户可感知功能）→ 应该开 PRD
- ❌ issue 里讨论架构 / 技术选型，最后一关闭就丢了 → 应升级 ADR
- ❌ 一个大 issue 持续几个月 → 应该拆 task 或升级 RFC
- ❌ commit / PR 不引用 issue → CI 应阻断
- ❌ issue 关闭后没沉淀关键决策

## 自查

- [ ] 当前变更适合用 issue（不是用户可感知功能）
- [ ] Bug issue 有复现步骤、环境、期望 vs 实际
- [ ] commit / PR 引用了 issue
- [ ] 长讨论 / 重要决策已升级到 RFC / ADR / Postmortem
- [ ] 升级后 issue 留了指针并关闭
