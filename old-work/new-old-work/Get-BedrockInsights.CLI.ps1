param(
  [string]$Region       = "us-east-1",
  [string]$Profile      = "default",
  [string]$LogGroupName = "bedrock-cloudwatch",

  [string]$StartIso     = "", # e.g. "2025-08-07T00:00:00Z"
  [string]$EndIso       = "", # e.g. "2025-08-07T23:59:59Z"

  [int]$Limit           = 50,
  [string]$JsonOut      = ".\bedrock-insights.json",
  [string]$MarkdownOut  = ".\bedrock-insights.md"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

function ToEpoch([datetime]$dt) { [int]([DateTimeOffset]$dt).ToUnixTimeSeconds() }
function Parse-IsoUtc([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  return ([DateTimeOffset]::Parse($s)).UtcDateTime
}

# Window (UTC)
if ($StartIso -and $EndIso) {
  $start = Parse-IsoUtc $StartIso
  $end   = Parse-IsoUtc $EndIso
} else {
  $end   = (Get-Date).ToUniversalTime()
  $start = $end.AddDays(-1)
}
$startEpoch = ToEpoch $start
$endEpoch   = ToEpoch $end

# Query to temp file to avoid quoting issues
$query = @'
fields
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
'@
if ($Limit -gt 0) { $query += "`n| limit $Limit`n" }

$tmpQuery = Join-Path $env:TEMP "cwli_query_$(Get-Random).sql"
Set-Content -Path $tmpQuery -Encoding UTF8 -Value $query

try {
  Write-Host "[Start] aws logs start-query" -ForegroundColor Cyan
  $qid = aws logs start-query `
    --region $Region --profile $Profile `
    --log-group-name $LogGroupName `
    --start-time $startEpoch --end-time $endEpoch `
    --query-string ("file://{0}" -f $tmpQuery) |
    ConvertFrom-Json | Select-Object -ExpandProperty queryId

  if (-not $qid) { throw "No queryId returned from start-query." }

  # Poll
  do {
    Start-Sleep -Seconds 1
    $resp = aws logs get-query-results `
      --region $Region --profile $Profile `
      --query-id $qid | ConvertFrom-Json
    $status = $resp.status
  } while ($status -in @("Running","Scheduled"))

  Write-Host ("[Done] Status: {0}" -f $status) -ForegroundColor Green

  # Flatten
  $rows = @()
  if ($resp.results) {
    foreach ($r in $resp.results) {
      $o = @{}
      foreach ($c in $r) { $o[$c.field] = $c.value }
      $rows += [pscustomobject]$o
    }
  }

  # JSON
  @($rows) | ConvertTo-Json -Depth 8 | Set-Content -Path $JsonOut -Encoding UTF8
  Write-Host ("Saved {0} rows → {1}" -f $rows.Count, $JsonOut) -ForegroundColor Yellow

  # Markdown
  $cols = @(
    "@timestamp","@ingestionTime","requestId","@aws.account","@aws.region",
    "invocationTime","accountId","@message","inferenceRegion",
    "input.inputTokenCount","anthropicVersion","output.outputTokenCount",
    "invocationId","outputModel","usageInputTokens","usageOutputTokens",
    "cacheCreateTokens","cacheReadTokens"
  )
  $nl = "`r`n"
  $md  = "**CloudWatch Logs Insights**  ${nl}"
  $md += "region: $Region  ${nl}"
  $md += "log-group-names: $LogGroupName  ${nl}"
  $md += "start-time: " + ($start.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")) + "  ${nl}"
  $md += "end-time: "   + ($end.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))   + "  ${nl}"
  $md += "query-string:${nl}```${nl}${query}```${nl}---${nl}"
  $md += "| " + ($cols -join " | ") + " |${nl}"
  $md += "| " + (($cols | ForEach-Object { "---" }) -join " | ") + " |${nl}"
  foreach ($r in $rows) {
    $vals = foreach ($c in $cols) { ($r.$c -replace "\r?\n"," ") }
    $md += "| " + (($vals | ForEach-Object { $_ }) -join " | ") + " |${nl}"
  }
  Set-Content -Encoding UTF8 -Path $MarkdownOut -Value $md
  Write-Host ("Saved Markdown → {0}" -f $MarkdownOut) -ForegroundColor Yellow
}
finally {
  Remove-Item -ErrorAction SilentlyContinue $tmpQuery
}
