**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: bedrock-cloudwatch  
start-time: 2025-08-18T14:10:00.000Z  
end-time: 2025-08-18T14:40:00.000Z  
query-string:
`${nl}fields
  @timestamp,
  @ingestionTime,
  requestId,
  @aws.account,
  @aws.region,
  timestamp                    as invocationTime,
  accountId,
  @message,
  inferenceRegion,
  input.inputTokenCount,
  input.inputBodyJson.anthropic_version  as anthropicVersion,
  output.outputTokenCount,
  output.outputBodyJson.id       as invocationId,
  output.outputBodyJson.model    as outputModel,
  output.outputBodyJson.usage.input_tokens    as usageInputTokens,
  output.outputBodyJson.usage.output_tokens   as usageOutputTokens,
  output.outputBodyJson.usage.cache_creation_input_tokens as cacheCreateTokens,
  output.outputBodyJson.usage.cache_read_input_tokens     as cacheReadTokens
| sort @timestamp desc
| limit 50
`${nl}---
| @timestamp | @ingestionTime | requestId | @aws.account | @aws.region | invocationTime | accountId | @message | inferenceRegion | input.inputTokenCount | anthropicVersion | output.outputTokenCount | invocationId | outputModel | usageInputTokens | usageOutputTokens | cacheCreateTokens | cacheReadTokens |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

