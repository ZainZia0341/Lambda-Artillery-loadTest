**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-15T12:42:46Z  
end-time: 2025-08-15T12:47:01Z  
query-string:
  `${nl}fields @timestamp, @ingestionTime, @requestId, @duration, @billedDuration, @initDuration, @memorySize, @maxMemoryUsed, @xrayTraceId, @xraySegmentId
| filter @message like /^REPORT/
| sort @timestamp desc
| limit 200
  `${nl}---
| @timestamp | @ingestionTime | @requestId | @duration | @billedDuration | @initDuration | @memorySize | @maxMemoryUsed | @xrayTraceId | @xraySegmentId |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

