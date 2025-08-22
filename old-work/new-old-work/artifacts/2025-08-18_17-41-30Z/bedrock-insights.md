# Bedrock Logs (CloudWatch Logs Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: bedrock-cloudwatch  
start-time: 2025-08-18T17:11:37Z  
end-time: 2025-08-18T18:12:49Z  
query-string:
```
fields
  @timestamp,
  @ingestionTime,
  requestId,
  @aws.account,
  @aws.region,
  timestamp as invocationTime,
  accountId,
  @message,
  inferenceRegion,
  input.inputTokenCount,
  input.inputBodyJson.anthropic_version as anthropicVersion,
  output.outputTokenCount,
  output.outputBodyJson.id as invocationId,
  output.outputBodyJson.model as outputModel,
  output.outputBodyJson.usage.input_tokens as usageInputTokens,
  output.outputBodyJson.usage.output_tokens as usageOutputTokens,
  output.outputBodyJson.usage.cache_creation_input_tokens as cacheCreateTokens,
  output.outputBodyJson.usage.cache_read_input_tokens as cacheReadTokens
| sort @timestamp desc
| limit 100
```
---
| @timestamp | requestId | invocationTime | invocationId | outputModel | input.inputTokenCount | output.outputTokenCount | usageInputTokens | usageOutputTokens | cacheCreateTokens | cacheReadTokens |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2025-08-18 17:20:44.000 | 2707becd-2319-4a48-a192-e59cea3a6bdf | 2025-08-18T17:20:44Z | msg_bdrk_01QC1185nz15eKW51hbZUzGe | claude-sonnet-4-20250514 | 219 | 109 | 219 | 109 |  |  |
| 2025-08-18 17:20:44.000 | 0264d1f7-fd49-432a-b7c1-57c23d53dc11 | 2025-08-18T17:20:44Z | msg_bdrk_01VkMs5DACFjnQQFzkRp8btn | claude-sonnet-4-20250514 | 219 | 109 | 219 | 109 |  |  |
| 2025-08-18 17:36:36.000 | 9f8af3cf-8530-4b0f-aafa-edb4e2acaabe | 2025-08-18T17:36:36Z | msg_bdrk_01SBmevkeVDuLf8CGHD8JTDq | claude-sonnet-4-20250514 | 219 | 109 | 219 | 109 |  |  |
| 2025-08-18 17:36:36.000 | 9585f45a-5b50-485f-84d9-6bb0652de13b | 2025-08-18T17:36:36Z | msg_bdrk_01DQ68aMt9G9USmFQNZhzq3d | claude-sonnet-4-20250514 | 219 | 112 | 219 | 112 |  |  |
| 2025-08-18 17:41:42.000 | 195e8828-dae0-4d4d-9d29-3a66a8bc0447 | 2025-08-18T17:41:42Z | msg_bdrk_01TGGQWv2cTVcD4fMU17Bf1J | claude-sonnet-4-20250514 | 219 | 96 | 219 | 96 |  |  |
| 2025-08-18 17:41:42.000 | ba121563-a541-430b-95c8-b5418a935a43 | 2025-08-18T17:41:42Z | msg_bdrk_012uvPgWpirAkETfRa7vmppa | claude-sonnet-4-20250514 | 219 | 108 | 219 | 108 |  |  |

