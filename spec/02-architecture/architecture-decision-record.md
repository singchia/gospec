# 02.2 - 架构决策记录（ADR）

> **适用**：写架构决策记录、回溯历史决策。
>
> ADR 记录的是"已经做出的决策"，关注**为什么这么选**，而不是"怎么实施"（怎么实施是 RFC / HLD / 代码的事）。

## 何时必须写 ADR

- 引入新的重要外部依赖
- 变更核心架构模式（如从单体拆分服务）
- 选择技术方案（如认证方案切换）
- 重大数据库 schema 变更
- 跨多个 domain 的接口设计

## ADR vs RFC

详细对比见 `01-requirement/technical-rfc.md`。一句话：

- **RFC** 是"提案 + 评审 + 实施"的完整载体（讲方案、备选、影响、排期）
- **ADR** 是"决策快照"（讲背景、选了什么、为什么、后果）
- 大型 RFC 实施过程中可能产出多个 ADR；小决策可以只写 ADR，跳过 RFC

## 编号与归档

- **编号**：`ADR-<三位序号>-<简述>` 如 `ADR-001-casdoor-auth`
- **路径**：`docs/adr/ADR-XXX-<简述>.md`
- **模板**：`docs/templates/architecture-decision-record-template.md`

## 状态流转

```
提议 → 已接受 → （后续）已废弃 / 已替代
```

- **提议**：草稿，等待评审
- **已接受**：决策生效
- **已废弃**：方案被否，但 ADR 文件**保留**作为历史
- **已替代**：被新 ADR 取代，新 ADR 在 header 写 `替代 ADR-YYY`

**关键**：ADR 一旦写下永不删除。决策错了就标"已废弃"或写新 ADR 替代，原文留档。

## 评审流程

1. 作者起草 ADR，状态「提议」
2. 在 PR 中评审，相关 owner 必须 review（见 `02-architecture/monorepo.md` CODEOWNERS）
3. 评审通过后状态置「已接受」
4. 合并到 main，归档到 `docs/adr/`

## 自查

- [ ] 编号唯一，命名清晰
- [ ] 背景、决策、备选、后果四段齐全
- [ ] 备选方案至少 2 个并说明取舍
- [ ] 已知正负影响都列出
- [ ] 涉及替代关系已写明被替代的 ADR 编号
- [ ] 模板使用 `docs/templates/architecture-decision-record-template.md`
