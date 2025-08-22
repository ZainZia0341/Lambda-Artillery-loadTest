$start = 1755506629
$end   = 1755508143
$q = @"
fields
  @timestamp,
  @ingestionTime,
  requestId,
  @aws.account,
  @aws.region,
  timestamp                              as invocationTime,
  accountId,
  @message,
  inferenceRegion,
  input.inputTokenCount,
  input.inputBodyJson.anthropic_version  as anthropicVersion,
  output.outputTokenCount,
  output.outputBodyJson.id               as invocationId,
  output.outputBodyJson.model            as outputModel,
  output.outputBodyJson.usage.input_tokens                  as usageInputTokens,
  output.outputBodyJson.usage.output_tokens                 as usageOutputTokens,
  output.outputBodyJson.usage.cache_creation_input_tokens   as cacheCreateTokens,
  output.outputBodyJson.usage.cache_read_input_tokens       as cacheReadTokens
| sort @timestamp desc
| limit 50
"@

$qid = aws logs start-query `
  --region us-east-1 `
  --profile default `
  --log-group-name bedrock-cloudwatch `
  --start-time $start --end-time $end `
  --query-string $q |
  ConvertFrom-Json | Select-Object -ExpandProperty queryId

aws logs get-query-results `
  --region us-east-1 `
  --profile default `
  --query-id $qid |
  Out-File -Encoding UTF8 .\bedrock-insights-utc.json

Write-Host "Saved -> .\bedrock-insights-utc.json"
