# 12.2 - On-Call、事故响应、Runbook、Postmortem

> 适用：值班、告警响应、写 Runbook、事故指挥、事后复盘。

## On-Call 值班

### 原则

- **主备双人**：主值班 + 备用值班
- **轮值周期**：1 周为宜，不超过 2 周
- **值班交接**：每周固定时间，走遗留问题清单
- **补偿机制**：响应告警有补偿（时间/津贴）

### 职责

1. 接收并响应告警（P0 5min / P1 15min / P2 1h）
2. 初步定位，按 Runbook 处理
3. 需要协作时 escalate 到研发负责人
4. 值班日报：当日告警数量、处理情况、遗留项

### Escalation 路径

```
告警 → 主值班 (5min 未响应)
     → 备值班 (5min 未响应)
     → 值班负责人
     → 研发负责人 / 技术总监
```

---

## 事故响应

### 事故分级

| 级别 | 定义 | SLA |
|------|------|-----|
| **P0** | 全站不可用、核心功能不可用、数据损坏/泄露 | 5min 响应，1h 恢复 |
| **P1** | 核心链路降级、SLO 严重违约 | 15min 响应，4h 恢复 |
| **P2** | 非核心功能异常、可绕行 | 1h 响应，1 工作日恢复 |
| **P3** | 体验问题、轻微异常 | 工作日跟进 |

### MTTR 四段论

```
Detect → Triage → Mitigate → Resolve → Learn
检测     定级     止血       根治      复盘
```

### 事故角色（P0/P1 必须指定）

| 角色 | 职责 |
|------|------|
| **IC** (Incident Commander) | 全局指挥，决策优先级，不亲自动手 |
| **Ops Lead** | 执行止血和恢复操作 |
| **Comms Lead** | 对外沟通（用户、客服、管理层） |
| **Scribe** | 记录时间线、决策、操作 |

### 止血优先原则

**先恢复，后定位**。可用的止血手段：

1. 回滚到上一个稳定版本
2. 切走流量 / 降级非核心功能
3. 扩容
4. 关闭 feature flag
5. 重启受影响实例

### 事故沟通模板

```markdown
[INCIDENT-2026-04-14-001] Edge 服务 P99 延迟升高

状态：处理中 / 已止血 / 已恢复
影响：edge API 调用 P99 > 3s，错误率 2%
影响用户：约 15%
开始时间：10:30
当前进展：
- 10:35 确认 edge-service-v2.3.0 部署后出现
- 10:40 开始回滚
- 10:45 回滚完成，指标恢复中
下次更新：11:00 或状态变化时
```

---

## Runbook

每个告警必须配 Runbook：

```yaml
- alert: HighHttpErrorRate
  annotations:
    runbook_url: "https://wiki.internal/runbooks/http-error-rate"
```

### Runbook 模板

存放路径：`docs/runbooks/<alert-name>.md`

```markdown
# Runbook: <告警名>

## 告警含义
简述业务含义和严重程度。

## 影响评估
- 影响哪些用户 / 功能
- 业务损失估算

## 快速诊断（前 5 分钟）
1. Grafana 面板：<link>
2. 链路追踪：<link>
3. 关键日志查询：
   ```bash
   kubectl logs -l app=liaison --tail=100 | grep ERROR
   ```

## 常见原因与处置
### 原因 A：数据库连接池耗尽
- 验证：`connection_pool_active / max` 接近 1
- 处置：
  1. 临时扩容
  2. 查慢查询
  3. 联系 DBA

## 止血手段
- [ ] 回滚：`kubectl rollout undo deploy/liaison`
- [ ] 降级：关闭 feature flag
- [ ] 扩容

## Escalation
- 10 min 无法止血 → 值班负责人
- 30 min 无法恢复 → 研发负责人
```

### 质量要求

- 每个告警都必须有对应 Runbook（无 Runbook 不允许上线）
- 每次事故后 review 并更新 Runbook
- 每季度演练一次（混沌工程，详见 `capacity.md`）

---

## Postmortem（事后复盘）

### 何时必须写

- 所有 P0 / P1 事故
- P2 涉及新类型问题
- Near-miss（差点成事故但被拦住）

### 无指责原则（Blameless）

- 对事不对人
- 假设每个人都做了当时认为正确的事
- 关注系统和流程如何改进，而非谁该背锅

### Postmortem 模板

存放路径：`docs/postmortems/<YYYY-MM-DD>-<简述>.md`

```markdown
# Postmortem: <事故标题>

- 日期：
- 持续时间：
- 级别：P0 / P1
- 作者：
- 状态：草稿 / 已评审 / 已归档

## 摘要（TL;DR）
一句话：发生了什么、影响了谁、持续多久、怎么恢复的。

## 影响
- 受影响用户：
- 业务影响：
- 数据影响：
- SLO 消耗：

## 事故时间线
| 时间 | 事件 |
|------|------|

## 根因分析（5 Whys）
1. 为什么 X？→ ...
2. ...

## 做对了什么
## 做错了什么

## Action Items
| ID | 动作 | Owner | Due | 优先级 |

## 经验教训
```

### Action Items 跟踪

- 必须有明确 owner 和 due date
- 纳入项目管理系统跟踪
- 每月 review 完成率，低于 80% 升级到管理层

## 自查

- [ ] 新告警有对应 Runbook
- [ ] 事故响应有指定 IC
- [ ] 优先止血而非定位
- [ ] P0/P1 事故 48h 内提交 Postmortem 草稿
- [ ] Action Items 有 owner 和 due date
