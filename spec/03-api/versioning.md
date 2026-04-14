# 03.4 - 版本演进、幂等性、限流响应

> **适用**：设计 API 版本演进策略、字段废弃、幂等性、限流响应、批量接口。

## API 版本演进

### 版本前缀

URL 必须带版本：`/api/v1/`、`/api/v2/`。Proto package 同步：`liaison.v1`、`liaison.v2`。

### 兼容性原则

| 类型 | 是否破坏 | 是否需要新版本 |
|------|---------|--------------|
| 新增 endpoint | ❌ 不破坏 | 不需要 |
| 新增可选字段 | ❌ 不破坏 | 不需要 |
| 字段加 `optional` | ❌ 不破坏 | 不需要 |
| 新增 enum 值 | ❌ 不破坏（但客户端要兼容 unknown） | 不需要 |
| 删除字段 | ✅ 破坏 | 需要 |
| 重命名字段 | ✅ 破坏 | 需要（或走 expand-contract） |
| 改字段类型 | ✅ 破坏 | 需要 |
| 改字段语义 | ✅ 破坏 | 需要 |
| 删除 endpoint | ✅ 破坏 | 需要 |

### Deprecation 流程

```protobuf
message ListEdgesResponse {
    repeated Edge data = 1;
    int64 total = 2;
    int64 next_cursor = 3 [deprecated = true]; // 标记废弃
}
```

```go
// ✅ Handler 在响应头加废弃提示
func (web *web) ListEdges(ctx context.Context, ...) (..., error) {
    if httpReq, ok := kratoshttp.RequestFromServerContext(ctx); ok {
        kratoshttp.SetResponseHeader(httpReq.Context(), "Deprecation", "true")
        kratoshttp.SetResponseHeader(httpReq.Context(), "Sunset", "Wed, 11 Nov 2026 23:59:59 GMT")
        kratoshttp.SetResponseHeader(httpReq.Context(), "Link", "</api/v2/edges>; rel=\"successor-version\"")
    }
    // ...
}
```

### 版本下线流程

```
Release 1: v2 上线，v1 标记 deprecated（响应头 + 文档）
Release 2-N: 监控 v1 流量，提示客户端迁移
Release Final: v1 流量降至阈值后，下线 v1
```

下线节奏：内部 API 1-3 个月，外部 API 6-12 个月。

监控 v1 调用方流量（详见 `10-observability/metrics.md`），通知具体调用方迁移。

---

## 幂等性

### 哪些接口必须幂等

- 所有 PUT / DELETE 接口（HTTP 语义要求）
- POST 接口中：支付、订单创建、消息发送、外部系统调用
- 任何会被客户端 / 网关重试的接口

### 实现方式

**方式 1：业务自然幂等**

```go
// ✅ 用唯一约束 + ON CONFLICT
INSERT INTO orders (out_trade_no, ...) VALUES (?, ...)
  ON DUPLICATE KEY UPDATE updated_at = NOW()
```

**方式 2：幂等键（Idempotency-Key）**

```go
// ✅ 客户端传 Idempotency-Key header，服务端缓存结果
func (s *PaymentService) Charge(ctx context.Context, req *ChargeRequest) (*ChargeResponse, error) {
    key := idempotencyKeyFromCtx(ctx)
    if cached, ok := s.cache.Get(key); ok {
        return cached.(*ChargeResponse), nil
    }
    resp, err := s.doCharge(ctx, req)
    if err == nil {
        s.cache.Set(key, resp, 24*time.Hour)
    }
    return resp, err
}
```

幂等键缓存 TTL 建议 24h。Redis 实现见 `04-data-model/redis.md`。

---

## 限流响应

被限流的请求必须返回标准格式：

```
HTTP 429 Too Many Requests
Retry-After: 30                    # 秒，告诉客户端何时重试
X-RateLimit-Limit: 100             # 时间窗口内总配额
X-RateLimit-Remaining: 0           # 剩余配额
X-RateLimit-Reset: 1731234567      # 配额重置时间戳
```

```json
{
  "code": 429,
  "message": "请求过于频繁，请稍后再试",
  "data": null
}
```

限流策略实现详见 `11-security/input-crypto.md`。

---

## 批量接口

### 命名

```
POST /api/v1/edges:batchCreate
POST /api/v1/edges:batchDelete
```

或 RPC 风格：

```
rpc BatchCreateEdges(BatchCreateEdgesRequest) returns (BatchCreateEdgesResponse);
```

### 部分成功

批量接口需要支持"部分成功"：

```protobuf
message BatchCreateEdgesResponse {
    int32 code = 1;
    string message = 2;
    BatchResult data = 3;
}

message BatchResult {
    repeated EdgeResult results = 1;
    int32 success_count = 2;
    int32 failed_count = 3;
}

message EdgeResult {
    int32 index = 1;       // 对应请求中的下标
    int32 code = 2;        // 单条结果的 code
    string error = 3;      // 单条失败原因
    Edge edge = 4;         // 成功时返回
}
```

**规则：**
- 单批数量上限：建议 100，最多 1000
- 整批失败 vs 部分失败：优先支持部分失败
- 必须幂等（`Idempotency-Key`）

---

## Cursor 分页（替代 page/page_size）

对深翻页友好的列表接口建议用 cursor：

```protobuf
message ListEdgesRequest {
    int32 page_size = 1;
    string page_token = 2;  // 上一次返回的 next_page_token
}

message ListEdgesResponse {
    repeated Edge data = 1;
    string next_page_token = 2;  // 空字符串表示无更多数据
}
```

实现见 `04-data-model/mysql.md` 的"游标分页"章节。

## 自查

- [ ] 破坏性变更走新版本，不在原版本改
- [ ] 废弃字段标 `deprecated`，响应头加 `Deprecation` / `Sunset`
- [ ] 写操作接口幂等（自然幂等 或 Idempotency-Key）
- [ ] 限流返回 `Retry-After` + `X-RateLimit-*`
- [ ] 批量接口支持部分成功
- [ ] 大数据量列表用 cursor 分页
