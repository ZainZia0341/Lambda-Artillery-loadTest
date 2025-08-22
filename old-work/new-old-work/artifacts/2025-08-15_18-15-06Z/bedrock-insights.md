# Bedrock Invocations (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: bedrock-cloudwatch  
start-time: 2025-08-15T18:05:15Z  
end-time: 2025-08-15T18:26:29Z  
query-string:
`$nlfields
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
| limit 50
`$nl---
| @timestamp | requestId | accountId | inferenceRegion | input.inputTokenCount | output.outputTokenCount | outputModel | usageInputTokens | usageOutputTokens |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2025-08-15 13:17:21.000 | 6309cd3c-be0d-4ba7-b7bf-5c9c28cfc30a | 663981805246 | us-east-2 | 219 | 85 | claude-sonnet-4-20250514 | 219 | 85 |
| 2025-08-15 13:17:21.000 | 8c9b3d07-b595-4594-baca-bbfd89d1b907 | 663981805246 | us-west-2 | 219 | 109 | claude-sonnet-4-20250514 | 219 | 109 |

