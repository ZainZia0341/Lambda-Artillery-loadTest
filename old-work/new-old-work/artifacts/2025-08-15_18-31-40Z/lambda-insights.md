# Lambda Logs (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-15T18:21:49Z  
end-time: 2025-08-15T18:43:03Z  
query-string:
`$nlfields @timestamp, @requestId, @duration, @billedDuration, @maxMemoryUsed, @memorySize, @initDuration
| filter @message like /^REPORT/
| sort @timestamp desc
| limit 100
`$nl---
| @timestamp | @requestId | @duration | @billedDuration | @maxMemoryUsed | @memorySize | @initDuration | @type |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2025-08-15 13:34:52.212 | 923b54a2-bd35-4d54-a9b9-90b36525a84a | 2894.13 | 2895 | 119000000 | 1024000000 | 944.22 |  |
| 2025-08-15 13:34:51.425 | aed443ac-f6df-48ce-bc7c-fc0513efbbba | 2220.96 | 2221 | 119000000 | 1024000000 | 834.66 |  |

