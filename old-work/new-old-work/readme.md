artillery run test-lambda-final.yml

artillery run --output artillery-metrics.json test-lambda-final.yml


\\ In Power Shell
$objs = Get-Content .\lambda-test.ndjson | % { $_ | ConvertFrom-Json }

@($objs) | ConvertTo-Json -Depth 20 | Set-Content .\report.json


.\run-load-and-collect.ps1 `
  -Region us-east-1 `
  -Profile default `
  -Yaml .\test-lambda-final.yml `
  -Ndjson .\lambda-test.ndjson `
  -LambdaLogGroup "/aws/lambda/ie-staging-claudeInvoker" `
  -BedrockLogGroup "bedrock-cloudwatch"



.\run-load-and-collect.ps1 `
  -Region us-east-1 `
  -Profile default `
  -Yaml .\test-lambda-final.yml `
  -Ndjson .\lambda-test.ndjson `
  -LambdaLogGroup "/aws/lambda/ie-staging-claudeInvoker" `
  -BedrockLogGroup "bedrock-cloudwatch" `
  -TimeBufferMinutes 10 `
  -IngestionDelaySeconds 60


.\Get-BedrockInsights.ps1 `
  -Region us-east-1 -ProfileName default -LogGroupName "bedrock-cloudwatch" `
  -StartIso "2025-08-15T00:00:00Z" -EndIso "2025-08-15T23:59:59Z" `
  -Limit 50 `
  -JsonOut .\bedrock-insights.json `
  -MarkdownOut .\bedrock-insights.md



.\Get-BedrockInsights.ps1 `
  -Region us-east-1 -Profile default -LogGroupName "bedrock-cloudwatch" `
  -StartIso "2025-08-15T00:00:00Z" -EndIso "2025-08-15T23:59:59Z" `
  -Limit 50 `
  -JsonOut .\bedrock-insights.json `
  -MarkdownOut .\bedrock-insights.md


 .\run-load-and-collect.ps1 `
   -Region us-east-1 -Profile default `
   -Yaml .\test-lambda-final.yml `
   -Ndjson .\lambda-test.ndjson `
   -LambdaLogGroup "/aws/lambda/ie-staging-claudeInvoker" `
   -BedrockLogGroup "bedrock-cloudwatch" `
   -TimeBufferMinutes 30 `
   -IngestionDelaySeconds 300

 .\run-load-and-collect.ps1



 .\Get-BedrockInsights.ps1 `
  -Region us-east-1 -Profile default -LogGroupName "bedrock-cloudwatch" `
  -StartIso "2025-08-18T14:10:00Z" -EndIso "2025-08-18T14:40:00Z" `
  -Limit 50 `
  -JsonOut .\bedrock-insights.json `
  -MarkdownOut .\bedrock-insights.md


  .\Get-BedrockInsights,CLI.ps1 `
  -Region us-east-1 -Profile default -LogGroupName "bedrock-cloudwatch" `
  -StartIso "2025-08-18T14:10:00Z" -EndIso "2025-08-18T14:40:00Z" `
  -Limit 50 `
  -JsonOut .\bedrock-insights2.json `
  -MarkdownOut .\bedrock-insights2.md


   .\run-load-and-collect.ps1 `
   -Region us-east-1 -Profile default `
   -Yaml .\test-lambda-final.yml `
   -Ndjson .\lambda-test.ndjson `
   -LambdaLogGroup "/aws/lambda/ie-staging-claudeInvoker" `
   -BedrockLogGroup "bedrock-cloudwatch" `
   -TimeBufferMinutes 30 `
   -IngestionDelaySeconds 60