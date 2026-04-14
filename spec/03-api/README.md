# 03 - 接口设计

> Proto 优先：所有 API 变更必须先更新 `.proto`，再生成代码，禁止直接修改生成文件。

## 何时读哪个

| 当前任务 | 读这个 |
|---------|--------|
| 写 / 改 proto 文件、消息命名、生成代码 | `proto.md` |
| 写 HTTP handler、路由、响应格式、错误映射、客户端 IP | `http.md` |
| 写 Swagger 注释、配认证中间件 | `middleware.md` |
| 设计 v1 → v2 演进、deprecation、幂等性、限流响应 | `versioning.md` |

## 核心原则（全局）

1. **Proto 是单一数据源**：所有 API 变更的入口
2. **统一响应格式**：`{code, message, data}`
3. **RESTful 路径 + 资源复数**
4. **错误用语义化错误码**，不只是 HTTP 状态码
5. **公开 handler 必须有 Swagger 注释**

## 强制约束（不可违反）

- 所有 API 变更先更新 `.proto`，不直接修改生成代码
- Handler 必须有 Swagger 注释：`@Summary`、`@Router`、`@Success` 缺一不可
- 响应格式统一：`{code, message, data}`
- v1 / v2 不可破坏性变更同版本，破坏变更走新版本
- 限流接口必须返回 `Retry-After` 和 `X-RateLimit-*` headers
