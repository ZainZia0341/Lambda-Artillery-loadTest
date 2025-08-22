**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-15T13:07:13Z  
end-time: 2025-08-15T13:29:27Z  
query-string:
  `${nl}fields @timestamp, @ingestionTime, @requestId, @duration, @billedDuration, @initDuration, @memorySize, @maxMemoryUsed, @xrayTraceId, @xraySegmentId
| filter @message like /^REPORT/
| sort @timestamp desc
| limit 10
  `${nl}---
| @timestamp | @ingestionTime | @requestId | @duration | @billedDuration | @initDuration | @memorySize | @maxMemoryUsed | @xrayTraceId | @xraySegmentId |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

