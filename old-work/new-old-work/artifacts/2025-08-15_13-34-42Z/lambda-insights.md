**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-15T13:24:42Z  
end-time: 2025-08-15T13:46:54Z  
query-string:
  `${nl}fields @timestamp, @ingestionTime, @requestId, @duration, @billedDuration, @initDuration, @memorySize, @maxMemoryUsed, @xrayTraceId, @xraySegmentId
| filter @message like /^REPORT/
| sort @timestamp desc
| limit 200
  `${nl}---
| @timestamp | @ingestionTime | @requestId | @duration | @billedDuration | @initDuration | @memorySize | @maxMemoryUsed | @xrayTraceId | @xraySegmentId |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

