# Bedrock Logs (CloudWatch Logs Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: bedrock-cloudwatch  
start-time: 2025-08-22T09:19:09Z  
end-time: 2025-08-22T10:20:23Z  
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
| @timestamp | requestId | invocationTime | invocationId | outputModel | inferenceRegion | input.inputTokenCount | output.outputTokenCount | usageInputTokens | usageOutputTokens | cacheCreateTokens | cacheReadTokens |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2025-08-22 09:41:06.000 | 0c0500e6-c4ad-4390-b16f-9c3d24f9f76b | 2025-08-22T09:41:06Z | msg_bdrk_01HiRycC5jcsxtYA5aZ1EBr3 | claude-sonnet-4-20250514 | us-west-2 | 219 | 109 | 219 | 109 |  |  |
| 2025-08-22 09:41:06.000 | ff1da00e-d2dd-4fa4-907c-beedb9e11605 | 2025-08-22T09:41:06Z | msg_bdrk_01WPZYqBe6CAouqhv39N8qXH | claude-sonnet-4-20250514 | us-east-2 | 219 | 109 | 219 | 109 |  |  |
| 2025-08-22 09:46:32.000 | 6ea3f570-37f5-4c75-93a7-2c71a492c24f | 2025-08-22T09:46:32Z | msg_bdrk_01XtJDNZAjEbBNeg6rrZqu9e | claude-sonnet-4-20250514 | us-west-2 | 219 | 106 | 219 | 106 |  |  |
| 2025-08-22 09:46:32.000 | a3fd1093-db3d-4491-a6bc-868d72de901b | 2025-08-22T09:46:32Z | msg_bdrk_014hCp4R9Jn1VZnyZHVTnJzu | claude-sonnet-4-20250514 | us-west-2 | 219 | 109 | 219 | 109 |  |  |
| 2025-08-22 09:49:15.000 | 02eb4735-770d-4a21-9113-c53db06d31b0 | 2025-08-22T09:49:15Z | msg_bdrk_01TFCjSKd9wnTFzB8Yhxeway | claude-sonnet-4-20250514 | us-east-1 | 219 | 87 | 219 | 87 |  |  |
| 2025-08-22 09:49:16.000 | 8c5ad1df-d547-4064-ac1d-589ae1d87f8f | 2025-08-22T09:49:16Z | msg_bdrk_01YVJG23zut8pBhtU1eLgjLt | claude-sonnet-4-20250514 | us-east-1 | 219 | 109 | 219 | 109 |  |  |

