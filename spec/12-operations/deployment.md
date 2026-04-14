# 12.1 - 部署、变更与发布

> 适用：部署上线、变更管理、回滚、feature flag、灰度发布。

## 部署策略对比

| 策略 | 适用 | 优点 | 缺点 |
|------|------|------|------|
| **滚动 (Rolling)** | 无状态服务、默认 | 资源占用少，自动化成熟 | 回滚慢，新旧版本兼容成本 |
| **蓝绿** | 快速切换、严格回滚 | 切换瞬时，回滚秒级 | 资源 2x |
| **金丝雀** | 高风险变更、核心链路 | 爆炸半径可控 | 流量切分复杂 |
| **重建** | 有状态单实例 | 简单 | 有停机窗口 |

### K8s 滚动更新示例

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 0
  minReadySeconds: 30
  progressDeadlineSeconds: 600
```

### 金丝雀流程

```
1%  流量 → 观察 15 min → 看 SLI（错误率/延迟/业务）
10% 流量 → 观察 30 min
50% 流量 → 观察 1 h
100% 流量
```

任一阶段 SLI 异常立即自动回滚。

---

## 变更管理

### 变更分级

| 级别 | 定义 | 审批 | 窗口 |
|------|------|------|------|
| **L1 常规** | 配置微调、文档、非核心 | 1 人 review | 工作日随时 |
| **L2 标准** | 功能发布、依赖升级 | 2 人 review + CI 通过 | 工作日白天 |
| **L3 重大** | 架构变更、Schema 迁移 | 架构委员会 + 灰度方案 | 变更窗口 |
| **L4 紧急** | 线上事故修复 | 值班负责人确认 | 随时 |

### 变更冻结

- 大促、营销活动、节假日前 24h 冻结
- 冻结期仅允许 L4
- 冻结窗口在 `docs/ops/change-freeze.md` 公示

### 变更单（CR）

L2+ 变更必须填写：

```markdown
# CR-<日期>-<序号>

- 变更人：
- 级别：
- 影响服务：
- 变更内容：
- 变更步骤：
- 回滚步骤：
- 验证方式：
- 预计时长：
- 开始时间：
```

---

## 回滚策略

### 回滚红线

**宁可误回滚，不要等确认**。观察到任一情况立即回滚：

- 错误率上升超基线 2x
- P99 延迟上升超基线 50%
- 业务核心指标下跌
- 出现 panic / OOM / 连接池耗尽
- 用户/客服反馈集中异常

### 回滚方式

| 资产 | 方式 |
|------|------|
| 应用代码 | `kubectl rollout undo` / ArgoCD 上一个 revision |
| 配置 | Git revert + 重新部署 |
| 数据库 schema | 反向 migration（详见 `13-database-migration/migration.md`） |
| 数据 | 从备份恢复（详见 `backup-dr.md`） |
| Feature flag | 控制台关闭开关（秒级） |

### 不可回滚变更

无法直接回滚的变更（如删除列、数据清理）：

1. **拆分为多次可回滚变更**：先停写、再停读、最后删除
2. **先扩展，后收缩**（expand & contract）
3. **开关保护**：新逻辑先双写 + feature flag 灰度

---

## Feature Flag

### 适用场景

- 新功能灰度（按用户、租户、百分比）
- A/B 测试
- Kill switch（快速关闭故障功能）
- 解耦部署与发布

### 技术选型

| 复杂度 | 方案 |
|--------|------|
| 简单 | 配置文件 + 热加载 |
| 中等 | Redis / etcd + SDK |
| 复杂 | Unleash / LaunchDarkly / GrowthBook |

### 使用示例

```go
if ff.IsEnabled(ctx, "edge.new_scheduler", ff.Attrs{
    UserID:   user.ID,
    TenantID: user.TenantID,
}) {
    return s.newScheduler.Schedule(ctx, req)
}
return s.legacyScheduler.Schedule(ctx, req)
```

### Flag 生命周期

- 每个 flag 必须有 `owner` 和 `expected_cleanup_date`
- 灰度完成后 **2 周内必须清理代码**
- 季度 review 长期存在的 flag

## 自查

- [ ] 变更已评估级别（L1/L2/L3）
- [ ] 有明确的回滚步骤
- [ ] 不可回滚变更已拆分
- [ ] 高风险变更用 feature flag 或金丝雀
- [ ] L2+ 已填写 CR 单
- [ ] 新 flag 有 owner 和 cleanup date
