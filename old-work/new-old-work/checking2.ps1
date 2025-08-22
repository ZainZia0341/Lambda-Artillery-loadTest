param(
  [string]$JsonFile = ".\bedrock-last-1m.json",
  [string]$OutFile  = ".\bedrock-last-1m.md"
)

$ErrorActionPreference = "Stop"

function Trunc([string]$s, [int]$n = 80) {
  if ($null -eq $s) { return "" }
  if ($s.Length -le $n) { return $s }
  return ($s.Substring(0, $n - 1) + "…")
}

# Load JSON (supports array OR line-delimited JSON)
$data = $null
try {
  $raw = Get-Content -Raw -ErrorAction Stop $JsonFile
  $data = $raw | ConvertFrom-Json
  if ($data -isnot [System.Collections.IEnumerable]) { $data = @($data) }
} catch {
  $data = @()
  foreach ($line in Get-Content $JsonFile) {
    $line = $line.Trim()
    if (-not $line) { continue }
    try { $data += ($line | ConvertFrom-Json) } catch {}
  }
}

if (-not $data) {
  "# Bedrock logs`r`n`r`n*(no records)*" | Set-Content -Path $OutFile -Encoding UTF8
  "Saved 0 rows -> $OutFile"
  exit 0
}

# Normalize each record:
#  - If '@message' exists (Insights), parse it as JSON.
#  - Else if 'message' exists (tail --format json), parse that if it's JSON; otherwise treat as raw.
$rows = foreach ($rec in $data) {
  $msgText = $null
  if ($rec.PSObject.Properties.Name -contains '@message') { $msgText = $rec.'@message' }
  elseif ($rec.PSObject.Properties.Name -contains 'message') { $msgText = $rec.message }

  $body = $null
  if ($msgText) {
    try { $body = $msgText | ConvertFrom-Json } catch { $body = $null }
  }

  # Timestamps
  $ts = $null
  if ($rec.PSObject.Properties.Name -contains '@timestamp') { $ts = $rec.'@timestamp' }
  elseif ($rec.PSObject.Properties.Name -contains 'timestamp') { $ts = $rec.timestamp }
  if (-not $ts -and $body -and $body.timestamp) { $ts = $body.timestamp }

  # Region(s)
  $region = if ($body -and $body.region) { $body.region } else { "" }
  $infReg = if ($body -and $body.inferenceRegion) { $body.inferenceRegion } else { "" }

  # Misc fields
  $reqId = if ($body -and $body.requestId) { $body.requestId } else { "" }
  $op    = if ($body -and $body.operation) { $body.operation } else { "" }
  $model = if ($body -and $body.modelId)   { $body.modelId   } else { "" }

  # Guardrail action (if present)
  $gr = ""
  try {
    if ($body.output -and $body.output.outputBodyJson) {
      $gr = $body.output.outputBodyJson.'amazon-bedrock-guardrailAction'
    }
    if (-not $gr -and $body.'amazon-bedrock-guardrailAction') {
      $gr = $body.'amazon-bedrock-guardrailAction'
    }
  } catch {}

  # Token counts
  $inTok  = $null
  $outTok = $null
  try {
    if ($body.output -and $body.output.outputBodyJson -and $body.output.outputBodyJson.usage) {
      $inTok  = $body.output.outputBodyJson.usage.input_tokens
      $outTok = $body.output.outputBodyJson.usage.output_tokens
    }
    if (-not $inTok -and $body.input -and $body.input.inputTokenCount) { $inTok = $body.input.inputTokenCount }
    if (-not $outTok -and $body.output -and $body.output.outputTokenCount) { $outTok = $body.output.outputTokenCount }
  } catch {}

  # Fallbacks
  if (-not $ts) { $ts = "" }
  if (-not $model -and $msgText -and -not $body) { $model = Trunc $msgText 90 } # raw message fallback

  [pscustomobject]@{
    TimestampUTC   = $ts
    Region         = $region
    Inference      = $infReg
    RequestId      = $reqId
    Operation      = $op
    Model          = Trunc $model 90
    Guardrail      = $gr
    InputTokens    = $inTok
    OutputTokens   = $outTok
  }
}

# Write Markdown
$nl = "`r`n"
$md  = "# Bedrock logs`r`n`r`n"
$md += "| Timestamp (UTC) | Region | Inference | RequestId | Operation | Model | Guardrail | In | Out |$nl"
$md += "|---|---|---|---|---|---|---|---:|---:|$nl"

foreach ($r in $rows) {
  $md += "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |{9}" -f `
    ($r.TimestampUTC -replace '\|','\|'),
    ($r.Region -replace '\|','\|'),
    ($r.Inference -replace '\|','\|'),
    ($r.RequestId -replace '\|','\|'),
    ($r.Operation -replace '\|','\|'),
    ($r.Model -replace '\|','\|'),
    ($r.Guardrail -replace '\|','\|'),
    ($r.InputTokens),
    ($r.OutputTokens),
    $nl
}

Set-Content -Path $OutFile -Encoding UTF8 -Value $md
"Saved {0} rows -> {1}" -f $rows.Count, $OutFile
