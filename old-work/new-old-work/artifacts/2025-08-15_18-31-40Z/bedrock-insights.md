# Bedrock Invocations (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: bedrock-cloudwatch  
start-time: 2025-08-15T18:21:49Z  
end-time: 2025-08-15T18:43:03Z  
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
| 2025-08-15 13:34:49.000 | 34daea42-5bdf-4f1a-a1f1-9a5db4287f77 | 663981805246 | us-west-2 | 219 | 108 | claude-sonnet-4-20250514 | 219 | 108 |
| 2025-08-15 13:34:49.000 | 14a77d2d-88a4-460f-b596-cbf56c205227 | 663981805246 | us-west-2 | 219 | 92 | claude-sonnet-4-20250514 | 219 | 92 |

