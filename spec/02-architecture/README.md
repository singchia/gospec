# 02 - 架构

> 涵盖**单服务内分层** + **跨服务的 monorepo 仓库结构** + **架构决策记录**。

## 何时读哪个

| 当前任务 | 读这个 |
|---------|--------|
| 设计单服务的内部分层、写业务模块、定接口 | `layering.md` |
| 初始化 monorepo、加新服务、决定 module 策略、配 CODEOWNERS | `monorepo.md` |
| 写 ADR（架构决策记录） | `architecture-decision-record.md` |
| 写 HLD（概要设计）/ 走新服务上线 checklist | `high-level-design.md` |

## 核心原则（全局）

1. **关注分离**：横向（分层）+ 纵向（领域）双重切分
2. **依赖单向**：上层依赖下层，禁止反向 / 循环
3. **接口在消费方定义**：实现细节对调用方透明
4. **每个领域有 owner**：CODEOWNERS 强制
5. **架构决策可追溯**：重要变更必须有 ADR

## 强制约束（不可违反）

- 单服务：`cmd → server → service → biz → data → model`，禁止跨层（`service` 不能直连 `data`）
- monorepo：`cmd/` 按 service 切，`internal/` 按 **Bounded Context** 切；跨 BC 禁止直接 import，必须通过 API / 事件 / `internal/pkg/`
- `internal/pkg/`、`model/` 不依赖任何业务层
- 依赖通过构造函数注入，不使用全局变量
- 涉及架构变更必须先写 ADR，确认后再编码
- 新服务上线前必须完成"新服务上线 Checklist"（详见 `high-level-design.md`）
