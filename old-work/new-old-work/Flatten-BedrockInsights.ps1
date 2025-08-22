param(
  [string]$InputJson   = ".\bedrock-insights.json",
  [string]$MarkdownOut = ".\bedrock-insights.md",
  [string]$Region      = "us-east-1",
  [string]$LogGroup    = "bedrock-cloudwatch",
  [string]$StartIso    = "2025-08-15T14:11:00Z",
  [string]$EndIso      = "2025-08-15T15:47:00Z",
  [string]$QueryText = @'
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
'@
)

$resp = Get-Content -Raw $InputJson | ConvertFrom-Json
$rows = foreach ($r in $resp.results) {
  $o = @{}
  foreach ($c in $r) { $o[$c.field] = $c.value }
  [pscustomobject]$o
}

$cols = @(
  '@timestamp','@ingestionTime','requestId','@aws.account','@aws.region',
  'invocationTime','accountId','@message','inferenceRegion','input.inputTokenCount',
  'anthropicVersion','output.outputTokenCount','invocationId','outputModel',
  'usageInputTokens','usageOutputTokens','cacheCreateTokens','cacheReadTokens'
)

$nl = "`r`n"
$md  = "**CloudWatch Logs Insights**  $nl"
$md += "region: $Region  $nl"
$md += "log-group-names: $LogGroup  $nl"
$md += "start-time: $StartIso  $nl"
$md += "end-time: $EndIso  $nl"
$md += "query-string:$nl```$nl$QueryText$nl```$nl---$nl"

# header
$md += "| " + ($cols -join " | ") + " |$nl"
$md += "| " + (($cols | ForEach-Object { '---' }) -join " | ") + " |$nl"

# rows
foreach ($r in $rows) {
  $vals = foreach ($c in $cols) {
    $v = $r.$c
    if ($null -eq $v) { "" } else { ($v -replace "\r?\n"," ") }
  }
  $md += "| " + ($vals -join " | ") + " |$nl"
}

Set-Content -Path $MarkdownOut -Value $md -Encoding UTF8
Write-Host "Saved Markdown -> $MarkdownOut  (rows: $($rows.Count))"
