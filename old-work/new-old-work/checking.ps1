# get-bedrock-last-hour.ps1
param(
    [string]$Region = "us-east-1",
    [string]$Profile = "default",
    [string]$LogGroupName = "bedrock-cloudwatch",
    [int]$LookbackMinutes = 1,
    [string]$OutFile = ".\bedrock-logs-last-hour.json"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

# Time window (epoch seconds)
$start = [int]([DateTimeOffset]::UtcNow.AddMinutes(-$LookbackMinutes)).ToUnixTimeSeconds()
$end = [int]([DateTimeOffset]::UtcNow).ToUnixTimeSeconds()

# Simple Insights query: latest first, up to 10k rows
$query = "fields @timestamp, @ingestionTime, @log, @logStream, @message | sort @timestamp desc | limit 10000"

# Start query
$qid = aws logs start-query `
    --region $Region `
    --profile $Profile `
    --log-group-name $LogGroupName `
    --start-time $start `
    --end-time $end `
    --query-string $query |
ConvertFrom-Json | Select-Object -ExpandProperty queryId

# Poll for completion (max ~60s)
for ($i = 0; $i -lt 60; $i++) {
    $resp = aws logs get-query-results `
        --region $Region `
        --profile $Profile `
        --query-id $qid | ConvertFrom-Json

    if ($resp.status -in @("Complete", "Failed", "Cancelled", "Timeout")) { break }
    Start-Sleep -Seconds 1
}

# Flatten rows -> array of objects
$rows = @()
if ($resp.results) {
    foreach ($r in $resp.results) {
        $o = @{}
        foreach ($c in $r) { $o[$c.field] = $c.value }
        $rows += [pscustomobject]$o
    }
}

# Save JSON
@($rows) | ConvertTo-Json -Depth 50 | Set-Content -Path $OutFile -Encoding UTF8

# Minimal console note
"Saved $($rows.Count) records to $OutFile"
