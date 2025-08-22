# Lambda Logs (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-15T18:05:15Z  
end-time: 2025-08-15T18:26:29Z  
query-string:
`$nlfields @timestamp, @requestId, @duration, @billedDuration, @maxMemoryUsed, @memorySize, @initDuration, @type
| filter @type = "REPORT"
| sort @timestamp desc
| limit 100
`$nl---
**No data found for this query**

