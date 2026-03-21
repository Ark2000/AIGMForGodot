# Content from https://platform.moonshot.cn/docs/api/balance

查询余额 - Kimi API 开放平台

🎉 最新发布 kimi k2.5 模型，支持多模态理解与处理，擅长解决更复杂的问题。

文档

API 接口说明

查询余额

# 查询余额

## 请求地址

```
GET https://api.moonshot.cn/v1/users/me/balance
```

## 调用示例

```
curl https://api.moonshot.cn/v1/users/me/balance -H "Authorization: Bearer $MOONSHOT_API_KEY"
```

## 返回内容

```
{
  "code": 0,
  "data": {
    "available_balance": 49.58894,
    "voucher_balance": 46.58893,
    "cash_balance": 3.00001
  },
  "scode": "0x0",
  "status": true
}
```

## 返回内容说明

| 字段 | 说明 | 类型 | 单位 |
| --- | --- | --- | --- |
| available_balance | 可用余额，包括现金余额和代金券余额, 当它小于等于 0 时, 用户不可调用推理 API | float | 人民币元（CNY） |
| voucher_balance | 代金券余额, 不会为负数 | float | 人民币元（CNY） |
| cash_balance | 现金余额, 可能为负数, 代表用户欠费, 当它为负数时,`available_balance`为`voucher_balance`的值 | float | 人民币元（CNY） |

[计算 Token](https://platform.moonshot.cn/docs/api/estimate) [模型推理定价](https://platform.moonshot.cn/docs/pricing/chat)
