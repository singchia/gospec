# 11.5 - 威胁建模

> 适用：新服务上线前、引入新认证机制、对外暴露新协议端口、处理新类型敏感数据时。

## 何时必须做

- 新服务上线前
- 引入新认证 / 授权机制
- 对外暴露新协议或端口
- 处理新类型的敏感数据（PII、支付、医疗）

## STRIDE 检查表

| 威胁类型 | 含义 | 典型缓解 |
|---------|------|---------|
| **S**poofing | 身份伪造 | 强认证、MFA、签名 |
| **T**ampering | 数据篡改 | HTTPS、签名、HMAC |
| **R**epudiation | 抵赖 | 审计日志、不可篡改存储 |
| **I**nformation Disclosure | 信息泄露 | 加密、最小返回字段 |
| **D**enial of Service | 拒绝服务 | 限流、熔断、配额 |
| **E**levation of Privilege | 权限提升 | RBAC、参数校验、最小权限 |

## 输出物

威胁建模结果记录到 `docs/security/threat-model-<service>.md`：

```markdown
# 威胁建模 — <服务名>

- 日期：YYYY-MM-DD
- 参与人：
- 系统范围：

## 数据流图
（图示：actor / process / data store / trust boundary）

## 资产清单
| 资产 | 价值 | 位置 |

## STRIDE 分析
| 威胁 | 类型 | 影响 | 现有缓解 | 待办 |

## Action Items
| ID | 动作 | Owner | Due |
```

## 自查

- [ ] 新服务前已完成 STRIDE 分析
- [ ] 数据流图标注 trust boundary
- [ ] 高风险威胁有 Action Item 跟进
- [ ] 输出文档归档到 `docs/security/`
