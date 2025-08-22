# Bedrock Invocations (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: bedrock-cloudwatch  
start-time: 2025-08-15T17:25:40Z  
end-time: 2025-08-15T17:46:53Z  
query-string:
`$nlfields
  @timestamp,
  requestId,
  accountId,
  inferenceRegion,
  input.inputTokenCount,
  output.outputTokenCount,
  output.outputBodyJson.model as model,
  output.outputBodyJson.usage.input_tokens as usageInputTokens,
  output.outputBodyJson.usage.output_tokens as usageOutputTokens
| sort @timestamp desc
| limit 100
`$nl---
| @timestamp | requestId | accountId | inferenceRegion | input.inputTokenCount | output.outputTokenCount | model | usageInputTokens | usageOutputTokens |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2025-08-15 12:44:54.000 | 85b25dcd-78a7-4ad2-9cfa-166ecd6034d8 | 663981805246 | us-east-2 | 219 | 109 | claude-sonnet-4-20250514 | 219 | 109 |
| 2025-08-15 12:44:54.000 | 9081a09f-d387-4e2a-a2fe-3a6163392508 | 663981805246 | us-east-1 | 219 | 109 | claude-sonnet-4-20250514 | 219 | 109 |

