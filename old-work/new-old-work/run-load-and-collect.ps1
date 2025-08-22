# run-load-and-collect-enhanced.ps1
param(
  [string]$Region              = "us-east-1",
  [string]$Profile             = "default",
  [string]$Yaml                = ".\test-lambda-final.yml",
  [string]$Ndjson              = ".\lambda-test.ndjson",
  [string]$LambdaLogGroup      = "/aws/lambda/ie-staging-claudeInvoker",
  [string]$BedrockLogGroup     = "bedrock-cloudwatch",
  [int]$TimeBufferMinutes      = 30,
  [int]$IngestionDelaySeconds  = 60
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"
$env:AWS_PAGER = ""

function Ensure-Dir($path) { 
  if (-not (Test-Path -LiteralPath $path)) { 
    New-Item -ItemType Directory -Force -Path $path | Out-Null 
  } 
}

# Convert DateTime to Unix milliseconds (for filter-log-events)
function To-UnixMilliseconds([DateTime]$dt) {
  $utcTime = if ($dt.Kind -eq [System.DateTimeKind]::Utc) { 
    $dt 
  } else { 
    $dt.ToUniversalTime() 
  }
  
  $unixEpoch = [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
  $timeSpan = $utcTime - $unixEpoch
  
  return [long]($timeSpan.TotalMilliseconds)
}

# Convert Unix milliseconds to DateTime
function From-UnixMilliseconds([long]$ms) {
  return [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc).AddMilliseconds($ms)
}

# Convert DateTime to Unix seconds
function To-UnixSeconds([DateTime]$dt) {
  $utcTime = if ($dt.Kind -eq [System.DateTimeKind]::Utc) { 
    $dt 
  } else { 
    $dt.ToUniversalTime() 
  }
  
  $unixEpoch = [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
  $timeSpan = $utcTime - $unixEpoch
  
  return [int][Math]::Floor($timeSpan.TotalSeconds)
}

function Test-LogGroupExists {
  param([string]$LogGroup)
  try {
    Write-Host "  Checking log group: $LogGroup" -ForegroundColor Gray
    
    $raw = aws --region $Region --profile $Profile logs describe-log-groups --log-group-name-prefix $LogGroup 2>&1
    
    $result = $null
    try { 
      $result = $raw | ConvertFrom-Json 
    } catch {
      Write-Host "  Failed to parse JSON: $($_.Exception.Message)" -ForegroundColor Yellow
      return $false
    }
    
    if (-not $result -or -not $result.logGroups) {
      Write-Host "  No log groups in response" -ForegroundColor Yellow
      return $false
    }
    
    $exists = $result.logGroups | Where-Object { $_.logGroupName -eq $LogGroup }
    if ($exists) {
      Write-Host "[OK] Log group found: $LogGroup" -ForegroundColor Green
      return $true
    } else {
      Write-Host "[MISS] Log group NOT found: $LogGroup" -ForegroundColor Red
      return $false
    }
  } catch {
    Write-Host "[ERR] Error checking log group: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

# Parse Lambda REPORT message to extract all CloudWatch Insights fields
function Parse-LambdaReport {
  param([string]$Message, [DateTime]$Timestamp, [DateTime]$IngestionTime, [string]$LogStream)
  
  $result = [PSCustomObject]@{
    '@timestamp' = $Timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff')
    '@ingestionTime' = $IngestionTime.ToString('yyyy-MM-dd HH:mm:ss.fff')
    '@requestId' = ''
    '@duration' = $null
    '@billedDuration' = $null
    '@initDuration' = $null
    '@memorySize' = $null
    '@maxMemoryUsed' = $null
    '@entity.KeyAttributes.Name' = 'ie-staging-claudeInvoker'
    '@entity.Attributes.Lambda.Function' = 'ie-staging-claudeInvoker'
    '@entity.Attributes.PlatformType' = 'AWS::Lambda'
    '@aws.account' = '663981805246'
    '@aws.region' = $Region
    '@xrayTraceId' = ''
    '@xraySegmentId' = ''
    '@logStreamName' = $LogStream
    '@message' = $Message
  }
  
  # Parse REPORT line
  if ($Message -match 'REPORT RequestId:\s+([a-f0-9-]+)') {
    $result.'@requestId' = $Matches[1]
  }
  
  if ($Message -match 'Duration:\s+([\d.]+)\s+ms') {
    $result.'@duration' = [double]$Matches[1]
  }
  
  if ($Message -match 'Billed Duration:\s+(\d+)\s+ms') {
    $result.'@billedDuration' = [int]$Matches[1]
  }
  
  if ($Message -match 'Init Duration:\s+([\d.]+)\s+ms') {
    $result.'@initDuration' = [double]$Matches[1]
  }
  
  if ($Message -match 'Memory Size:\s+(\d+)\s+MB') {
    $result.'@memorySize' = [int]$Matches[1] * 1000000  # Convert to bytes
  }
  
  if ($Message -match 'Max Memory Used:\s+(\d+)\s+MB') {
    $result.'@maxMemoryUsed' = [int]$Matches[1] * 1000000  # Convert to bytes
  }
  
  # Extract X-Ray trace IDs if present in log stream
  if ($LogStream -match '\[([a-f0-9-]+)\]([a-f0-9]+)') {
    $result.'@xrayTraceId' = "1-" + $Matches[1].Substring(0,8) + "-" + $Matches[1].Substring(8)
    $result.'@xraySegmentId' = $Matches[2]
  }
  
  return $result
}

# Parse Bedrock invocation message to extract all CloudWatch Insights fields
function Parse-BedrockInvocation {
  param([string]$Message, [DateTime]$Timestamp, [DateTime]$IngestionTime)
  
  $result = [PSCustomObject]@{
    '@timestamp' = $Timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff')
    '@ingestionTime' = $IngestionTime.ToString('yyyy-MM-dd HH:mm:ss.fff')
    'requestId' = ''
    '@aws.account' = '663981805246'
    '@aws.region' = $Region
    'invocationTime' = ''
    'accountId' = ''
    '@message' = $Message
    'inferenceRegion' = ''
    'input.inputTokenCount' = $null
    'anthropicVersion' = ''
    'output.outputTokenCount' = $null
    'invocationId' = ''
    'outputModel' = ''
    'usageInputTokens' = $null
    'usageOutputTokens' = $null
    'cacheCreateTokens' = $null
    'cacheReadTokens' = $null
  }
  
  # Try to parse as JSON
  try {
    $json = $Message | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($json) {
      # Extract fields from JSON structure
      if ($json.timestamp) { $result.'invocationTime' = $json.timestamp }
      if ($json.accountId) { $result.'accountId' = $json.accountId }
      if ($json.requestId) { $result.'requestId' = $json.requestId }
      if ($json.inferenceRegion) { $result.'inferenceRegion' = $json.inferenceRegion }
      
      # Input fields
      if ($json.input) {
        if ($json.input.inputTokenCount) { 
          $result.'input.inputTokenCount' = $json.input.inputTokenCount 
        }
        if ($json.input.inputBodyJson) {
          if ($json.input.inputBodyJson.anthropic_version) {
            $result.'anthropicVersion' = $json.input.inputBodyJson.anthropic_version
          }
        }
      }
      
      # Output fields
      if ($json.output) {
        if ($json.output.outputTokenCount) { 
          $result.'output.outputTokenCount' = $json.output.outputTokenCount 
        }
        if ($json.output.outputBodyJson) {
          if ($json.output.outputBodyJson.id) {
            $result.'invocationId' = $json.output.outputBodyJson.id
          }
          if ($json.output.outputBodyJson.model) {
            $result.'outputModel' = $json.output.outputBodyJson.model
          }
          if ($json.output.outputBodyJson.usage) {
            $usage = $json.output.outputBodyJson.usage
            if ($usage.input_tokens) { $result.'usageInputTokens' = $usage.input_tokens }
            if ($usage.output_tokens) { $result.'usageOutputTokens' = $usage.output_tokens }
            if ($usage.cache_creation_input_tokens) { 
              $result.'cacheCreateTokens' = $usage.cache_creation_input_tokens 
            }
            if ($usage.cache_read_input_tokens) { 
              $result.'cacheReadTokens' = $usage.cache_read_input_tokens 
            }
          }
        }
      }
    }
  } catch {
    # If not JSON, keep the original message
  }
  
  return $result
}

# Get log events using filter-log-events
function Get-LogEvents {
  param(
    [string]$LogGroupName,
    [DateTime]$StartTime,
    [DateTime]$EndTime,
    [string]$Label,
    [int]$MaxItems = 200
  )
  
  $startMs = To-UnixMilliseconds $StartTime
  $endMs = To-UnixMilliseconds $EndTime
  
  Write-Host ("[QUERY] {0} group: {1}" -f $Label, $LogGroupName) -ForegroundColor Cyan
  Write-Host ("         UTC range: {0} → {1}" -f $StartTime.ToString('yyyy-MM-dd HH:mm:ss'), $EndTime.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Gray
  Write-Host ("         Epoch ms: {0} → {1}" -f $startMs, $endMs) -ForegroundColor Gray
  
  try {
    $result = aws logs filter-log-events `
      --log-group-name $LogGroupName `
      --start-time $startMs `
      --end-time $endMs `
      --region $Region `
      --profile $Profile `
      --max-items $MaxItems `
      --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
      Write-Host "[ERR] AWS CLI failed: $result" -ForegroundColor Red
      return @()
    }
    
    $parsed = $result | ConvertFrom-Json
    
    if ($parsed.events) {
      $count = $parsed.events.Count
      Write-Host ("         Found {0} log events" -f $count) -ForegroundColor Green
      return $parsed.events
    } else {
      Write-Host "         No events found" -ForegroundColor Yellow
      return @()
    }
  } catch {
    Write-Host "[ERR] Failed to get log events: $($_.Exception.Message)" -ForegroundColor Red
    return @()
  }
}

# Write CloudWatch Logs Insights formatted markdown table
function Write-CloudWatchInsightsMarkdown {
  param(
    [string]$OutFile,
    [string]$Title,
    [string]$RegionStr,
    [string]$LogGroup,
    [DateTime]$StartTime,
    [DateTime]$EndTime,
    [object[]]$Rows,
    [string[]]$Columns,
    [string]$QueryString
  )
  
  $nl = "`r`n"
  $md = "# $Title$nl$nl"
  $md += "**CloudWatch Logs Insights**  $nl"
  $md += "region: $RegionStr  $nl"
  $md += "log-group-names: $LogGroup  $nl"
  $md += "start-time: " + ($StartTime.ToString("yyyy-MM-ddTHH:mm:ssZ")) + "  $nl"
  $md += "end-time: " + ($EndTime.ToString("yyyy-MM-ddTHH:mm:ssZ")) + "  $nl"
  $md += "query-string:$nl``````$nl$QueryString$nl``````$nl"
  $md += "---$nl"

  if (-not $Rows -or $Rows.Count -eq 0) {
    $md += "**No data found for this query**$nl"
  } else {
    $md += "| " + ($Columns -join " | ") + " |$nl"
    $md += "| " + (($Columns | ForEach-Object { '---' }) -join " | ") + " |$nl"
    
    foreach ($r in $Rows) {
      $vals = foreach ($c in $Columns) {
        $v = $r.$c
        if ($null -eq $v) { 
          "" 
        } else {
          $str = $v.ToString() -replace "\r?\n"," "
          # Truncate very long fields for markdown readability
          if ($c -eq "@message" -and $str.Length -gt 200) {
            $str.Substring(0, 200) + "..."
          } elseif ($str.Length -gt 100) {
            $str.Substring(0, 100) + "..."
          } else {
            $str
          }
        }
      }
      $md += "| " + ($vals -join " | ") + " |$nl"
    }
  }
  
  Set-Content -Path $OutFile -Value $md -Encoding UTF8
}

# Main execution starts here
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " ARTILLERY LOAD TEST WITH LOG COLLECTION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Create timestamped output folder
$stamp = [DateTime]::UtcNow.ToString("yyyy-MM-dd_HH-mm-ss") + "Z"
$BaseOut = Join-Path "." ("artifacts\" + $stamp)
Ensure-Dir $BaseOut

$ArtilleryOut   = Join-Path $BaseOut "artillery-metrics.json"
$NdjsonOut      = Join-Path $BaseOut (Split-Path -Leaf $Ndjson)
$PrettyJsonOut  = Join-Path $BaseOut "report.json"
$LambdaJsonOut  = Join-Path $BaseOut "lambda-insights.json"
$BedrockJsonOut = Join-Path $BaseOut "bedrock-insights.json"
$LambdaMdOut    = Join-Path $BaseOut "lambda-insights.md"
$BedrockMdOut   = Join-Path $BaseOut "bedrock-insights.md"

# Verify log groups exist
Write-Host "`nSTEP 0: Verifying log groups..." -ForegroundColor Yellow
$lambdaExists = Test-LogGroupExists -LogGroup $LambdaLogGroup
$bedrockExists = Test-LogGroupExists -LogGroup $BedrockLogGroup

if (-not $lambdaExists -and -not $bedrockExists) {
  Write-Host ""
  Write-Host "[CRITICAL] Both log groups are missing." -ForegroundColor Red
  Write-Host "Do you want to continue anyway? (y/N): " -NoNewline -ForegroundColor Yellow
  $response = Read-Host
  if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "Exiting..." -ForegroundColor Yellow
    exit 1
  }
}

Write-Host ""
Write-Host "Press any key to continue with the test..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Record test start time
Write-Host "`nSTEP 1: Recording test start time..." -ForegroundColor Yellow
$testStart = [DateTime]::UtcNow
Write-Host ("Test started at: {0} UTC" -f $testStart.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Green

# Run Artillery
Write-Host "`nSTEP 2: Running Artillery load test..." -ForegroundColor Yellow
$env:REPORT_FILE = $NdjsonOut
artillery run --output $ArtilleryOut $Yaml
if ($LASTEXITCODE -ne 0) { 
  Write-Host "[WARN] Artillery exited with code $LASTEXITCODE" -ForegroundColor Yellow
}
$testEnd = [DateTime]::UtcNow
Write-Host ("Test ended at: {0} UTC" -f $testEnd.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Green
Write-Host ("Test duration: {0} seconds" -f [Math]::Round(($testEnd - $testStart).TotalSeconds, 1)) -ForegroundColor Green

# Process Artillery results
Write-Host "`nSTEP 3: Processing Artillery results..." -ForegroundColor Yellow
$objs = @()
if (Test-Path $NdjsonOut) { 
  $objs = Get-Content $NdjsonOut | ForEach-Object { $_ | ConvertFrom-Json } 
}
@($objs) | ConvertTo-Json -Depth 30 | Set-Content $PrettyJsonOut
Write-Host ("[OK] {0} per-request records -> {1}" -f ($objs.Count), $PrettyJsonOut) -ForegroundColor Green

# Wait for CloudWatch ingestion
Write-Host "`nSTEP 4: Waiting for CloudWatch ingestion..." -ForegroundColor Yellow
Write-Host ("Waiting {0} seconds for CloudWatch log ingestion..." -f $IngestionDelaySeconds) -ForegroundColor Cyan
for ($i = $IngestionDelaySeconds; $i -gt 0; $i -= 10) {
  Write-Host ("  {0} seconds remaining..." -f $i) -ForegroundColor Gray
  Start-Sleep -Seconds ([Math]::Min(10, $i))
}

# Set query window with buffer
Write-Host "`nSTEP 5: Setting query time window..." -ForegroundColor Yellow
$startQ = $testStart.AddMinutes(-$TimeBufferMinutes)
$endQ = [DateTime]::UtcNow.AddMinutes($TimeBufferMinutes)
Write-Host ("Query window: {0} to {1} UTC" -f $startQ.ToString('yyyy-MM-dd HH:mm:ss'), $endQ.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Green
Write-Host ("Window duration: {0} minutes" -f [Math]::Round(($endQ - $startQ).TotalMinutes, 1)) -ForegroundColor Green

# Query and parse Lambda logs
Write-Host "`nSTEP 6: Querying and parsing Lambda logs..." -ForegroundColor Yellow

# CloudWatch Insights query format for Lambda
$lambdaQueryString = @"
fields 
  @timestamp,
  @ingestionTime,
  @requestId,
  @duration,
  @billedDuration,
  @initDuration,
  @memorySize,
  @maxMemoryUsed,
  @entity.KeyAttributes.Name,
  @entity.Attributes.Lambda.Function,
  @entity.Attributes.PlatformType,
  @aws.account,
  @aws.region,
  @xrayTraceId,
  @xraySegmentId
| filter @message like /^REPORT/
| sort @timestamp desc
| limit 100
"@

if ($lambdaExists) {
  $rawEvents = Get-LogEvents -LogGroupName $LambdaLogGroup -StartTime $startQ -EndTime $endQ -Label "Lambda" -MaxItems 500
  
  if ($rawEvents -and $rawEvents.Count -gt 0) {
    # Parse all events, focusing on REPORT lines
    $allParsedEvents = @()
    $reportEvents = @()
    
    foreach ($event in $rawEvents) {
      $timestamp = From-UnixMilliseconds $event.timestamp
      $ingestionTime = From-UnixMilliseconds $event.ingestionTime
      
      if ($event.message -like '*REPORT RequestId*') {
        $parsed = Parse-LambdaReport -Message $event.message -Timestamp $timestamp -IngestionTime $ingestionTime -LogStream $event.logStreamName
        $reportEvents += $parsed
        $allParsedEvents += $parsed
      } else {
        # Keep other events in simple format
        $allParsedEvents += [PSCustomObject]@{
          '@timestamp' = $timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff')
          '@message' = $event.message
          '@logStreamName' = $event.logStreamName
        }
      }
    }
    
    Write-Host ("  Found {0} REPORT entries out of {1} total events" -f $reportEvents.Count, $rawEvents.Count) -ForegroundColor Cyan
    
    # Save detailed JSON with all parsed fields
    $jsonReport = @{
      results = $reportEvents | ForEach-Object {
        @(
          @{ field = "@timestamp"; value = $_.'@timestamp' },
          @{ field = "@ingestionTime"; value = $_.'@ingestionTime' },
          @{ field = "@requestId"; value = $_.'@requestId' },
          @{ field = "@duration"; value = $_.'@duration' },
          @{ field = "@billedDuration"; value = $_.'@billedDuration' },
          @{ field = "@initDuration"; value = $_.'@initDuration' },
          @{ field = "@memorySize"; value = $_.'@memorySize' },
          @{ field = "@maxMemoryUsed"; value = $_.'@maxMemoryUsed' },
          @{ field = "@entity.KeyAttributes.Name"; value = $_.'@entity.KeyAttributes.Name' },
          @{ field = "@entity.Attributes.Lambda.Function"; value = $_.'@entity.Attributes.Lambda.Function' },
          @{ field = "@entity.Attributes.PlatformType"; value = $_.'@entity.Attributes.PlatformType' },
          @{ field = "@aws.account"; value = $_.'@aws.account' },
          @{ field = "@aws.region"; value = $_.'@aws.region' },
          @{ field = "@xrayTraceId"; value = $_.'@xrayTraceId' },
          @{ field = "@xraySegmentId"; value = $_.'@xraySegmentId' }
        )
      }
      statistics = @{
        recordsMatched = $reportEvents.Count
        recordsScanned = $rawEvents.Count
        bytesScanned = 0
      }
      status = "Complete"
    }
    $jsonReport | ConvertTo-Json -Depth 10 | Set-Content $LambdaJsonOut -Encoding UTF8
    
    # Create CloudWatch Logs Insights formatted markdown
    $lambdaCols = @(
      '@timestamp', '@ingestionTime', '@requestId', '@duration', '@billedDuration',
      '@initDuration', '@memorySize', '@maxMemoryUsed', '@entity.KeyAttributes.Name',
      '@entity.Attributes.Lambda.Function', '@entity.Attributes.PlatformType',
      '@aws.account', '@aws.region', '@xrayTraceId', '@xraySegmentId'
    )
    
    Write-CloudWatchInsightsMarkdown -OutFile $LambdaMdOut `
      -Title "Lambda Logs (CloudWatch Logs Insights)" -RegionStr $Region -LogGroup $LambdaLogGroup `
      -StartTime $startQ -EndTime $endQ `
      -Rows $reportEvents `
      -Columns $lambdaCols `
      -QueryString $lambdaQueryString
    
    Write-Host ("[SUCCESS] Lambda: {0} total events, {1} REPORT entries" -f $rawEvents.Count, $reportEvents.Count) -ForegroundColor Green
    
    # Extract metrics summary
    if ($reportEvents.Count -gt 0) {
      $metrics = $reportEvents | Where-Object { $_.'@duration' -ne $null }
      if ($metrics) {
        $stats = @{
          TotalInvocations = $metrics.Count
          AverageDuration = [Math]::Round(($metrics.'@duration' | Measure-Object -Average).Average, 2)
          MaxDuration = ($metrics.'@duration' | Measure-Object -Maximum).Maximum
          MinDuration = ($metrics.'@duration' | Measure-Object -Minimum).Minimum
          AverageMemoryUsed = [Math]::Round((($metrics.'@maxMemoryUsed' | Where-Object { $_ -gt 0 }) | Measure-Object -Average).Average / 1000000, 2)
          MaxMemoryUsed = (($metrics.'@maxMemoryUsed' | Where-Object { $_ -gt 0 }) | Measure-Object -Maximum).Maximum / 1000000
        }
        
        Write-Host "`n  Lambda Performance Summary:" -ForegroundColor Cyan
        Write-Host ("    Invocations: {0}" -f $stats.TotalInvocations) -ForegroundColor Gray
        Write-Host ("    Duration: Avg={0}ms, Min={1}ms, Max={2}ms" -f $stats.AverageDuration, $stats.MinDuration, $stats.MaxDuration) -ForegroundColor Gray
        Write-Host ("    Memory: Avg={0}MB, Max={1}MB" -f $stats.AverageMemoryUsed, $stats.MaxMemoryUsed) -ForegroundColor Gray
        
        $statsFile = Join-Path $BaseOut "lambda-performance-stats.json"
        $stats | ConvertTo-Json | Set-Content $statsFile -Encoding UTF8
      }
    }
  } else {
    Write-Host "[INFO] No Lambda logs found in the time window" -ForegroundColor Yellow
    "No logs found for time window" | Set-Content $LambdaMdOut
    @{} | ConvertTo-Json | Set-Content $LambdaJsonOut
  }
} else {
  "Log group not found: $LambdaLogGroup" | Set-Content $LambdaMdOut
  @{} | ConvertTo-Json | Set-Content $LambdaJsonOut
  Write-Host "[SKIP] Lambda log group not found" -ForegroundColor Yellow
}

# Query and parse Bedrock logs
Write-Host "`nSTEP 7: Querying and parsing Bedrock logs..." -ForegroundColor Yellow

# CloudWatch Insights query format for Bedrock
$bedrockQueryString = @"
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
"@

if ($bedrockExists) {
  $rawEvents = Get-LogEvents -LogGroupName $BedrockLogGroup -StartTime $startQ -EndTime $endQ -Label "Bedrock" -MaxItems 200
  
    if ($rawEvents -and $rawEvents.Count -gt 0) {
      # Parse all Bedrock events
      $parsedEvents = @()
      
      foreach ($event in $rawEvents) {
        $timestamp = From-UnixMilliseconds $event.timestamp
        $ingestionTime = From-UnixMilliseconds $event.ingestionTime
        
        $parsed = Parse-BedrockInvocation -Message $event.message -Timestamp $timestamp -IngestionTime $ingestionTime
        $parsedEvents += $parsed
      }
      
      Write-Host ("  Parsed {0} Bedrock invocation events" -f $parsedEvents.Count) -ForegroundColor Cyan
      
      # Save detailed JSON in CloudWatch Insights format
      $jsonReport = @{
        results = $parsedEvents | ForEach-Object {
          @(
            @{ field = "@timestamp"; value = $_.'@timestamp' },
            @{ field = "@ingestionTime"; value = $_.'@ingestionTime' },
            @{ field = "requestId"; value = $_.'requestId' },
            @{ field = "@aws.account"; value = $_.'@aws.account' },
            @{ field = "@aws.region"; value = $_.'@aws.region' },
            @{ field = "invocationTime"; value = $_.'invocationTime' },
            @{ field = "accountId"; value = $_.'accountId' },
            @{ field = "@message"; value = $_.'@message' },
            @{ field = "inferenceRegion"; value = $_.'inferenceRegion' },
            @{ field = "input.inputTokenCount"; value = $_.'input.inputTokenCount' },
            @{ field = "anthropicVersion"; value = $_.'anthropicVersion' },
            @{ field = "output.outputTokenCount"; value = $_.'output.outputTokenCount' },
            @{ field = "invocationId"; value = $_.'invocationId' },
            @{ field = "outputModel"; value = $_.'outputModel' },
            @{ field = "usageInputTokens"; value = $_.'usageInputTokens' },
            @{ field = "usageOutputTokens"; value = $_.'usageOutputTokens' },
            @{ field = "cacheCreateTokens"; value = $_.'cacheCreateTokens' },
            @{ field = "cacheReadTokens"; value = $_.'cacheReadTokens' }
          )
        }
        statistics = @{
          recordsMatched = $parsedEvents.Count
          recordsScanned = $rawEvents.Count
          bytesScanned = 0
        }
        status = "Complete"
      }
      $jsonReport | ConvertTo-Json -Depth 10 | Set-Content $BedrockJsonOut -Encoding UTF8
      
      # Create CloudWatch Logs Insights formatted markdown
      $bedrockCols = @(
        '@timestamp', 'requestId', 'invocationTime', 'invocationId', 'outputModel',
        'input.inputTokenCount', 'output.outputTokenCount', 'usageInputTokens', 
        'usageOutputTokens', 'cacheCreateTokens', 'cacheReadTokens'
      )
      
      Write-CloudWatchInsightsMarkdown -OutFile $BedrockMdOut `
        -Title "Bedrock Logs (CloudWatch Logs Insights)" -RegionStr $Region -LogGroup $BedrockLogGroup `
        -StartTime $startQ -EndTime $endQ `
        -Rows $parsedEvents `
        -Columns $bedrockCols `
        -QueryString $bedrockQueryString
      
      Write-Host ("[SUCCESS] Bedrock: {0} invocation events found" -f $parsedEvents.Count) -ForegroundColor Green

      # Extract metrics summary
      if ($parsedEvents.Count -gt 0) {
        $metrics = $parsedEvents | Where-Object { $_.'usageInputTokens' -ne $null }
        if ($metrics) {
          $stats = @{
            TotalInvocations = $metrics.Count
            AverageInputTokens = [Math]::Round(($metrics.'usageInputTokens' | Measure-Object -Average).Average, 2)
            MaxInputTokens = ($metrics.'usageInputTokens' | Measure-Object -Maximum).Maximum
            AverageOutputTokens = [Math]::Round(($metrics.'usageOutputTokens' | Measure-Object -Average).Average, 2)
            MaxOutputTokens = ($metrics.'usageOutputTokens' | Measure-Object -Maximum).Maximum
            TotalInputTokens = ($metrics.'usageInputTokens' | Measure-Object -Sum).Sum
            TotalOutputTokens = ($metrics.'usageOutputTokens' | Measure-Object -Sum).Sum
          }
          
          Write-Host "`n  Bedrock Token Summary:" -ForegroundColor Cyan
          Write-Host ("    Invocations: {0}" -f $stats.TotalInvocations) -ForegroundColor Gray
          Write-Host ("    Input Tokens: Avg={0}, Max={1}" -f $stats.AverageInputTokens, $stats.MaxInputTokens) -ForegroundColor Gray
          Write-Host ("    Output Tokens: Avg={0}, Max={1}" -f $stats.AverageOutputTokens, $stats.MaxOutputTokens) -ForegroundColor Gray
          Write-Host ("    Total Tokens: Input={0}, Output={1}" -f $stats.TotalInputTokens, $stats.TotalOutputTokens) -ForegroundColor Gray

          $statsFile = Join-Path $BaseOut "bedrock-token-stats.json"
          $stats | ConvertTo-Json | Set-Content $statsFile -Encoding UTF8
        }
      }

    } else {
      Write-Host "[INFO] No Bedrock logs found in the time window" -ForegroundColor Yellow
      "No logs found for time window" | Set-Content $BedrockMdOut
      @{} | ConvertTo-Json | Set-Content $BedrockJsonOut
    }
} else {
    "Log group not found: $BedrockLogGroup" | Set-Content $BedrockMdOut
    @{} | ConvertTo-Json | Set-Content $BedrockJsonOut
    Write-Host "[SKIP] Bedrock log group not found" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " TEST COMPLETE" -ForegroundColor Cyan
Write-Host " Artifacts saved to: $BaseOut" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# End of script