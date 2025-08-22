# Lambda Logs (CloudWatch Logs Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-22T09:19:09Z  
end-time: 2025-08-22T10:20:23Z  
query-string:
```
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
```
---
| @timestamp | @ingestionTime | @requestId | @duration | @billedDuration | @initDuration | @memorySize | @maxMemoryUsed | @entity.KeyAttributes.Name | @entity.Attributes.Lambda.Function | @entity.Attributes.PlatformType | @aws.account | @aws.region | @xrayTraceId | @xraySegmentId |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2025-08-22 09:41:08.560 | 2025-08-22 09:41:17.556 | fe51ae72-af54-48ea-a8ab-992201d15f11 | 2455 | 2455 | 1019.38 | 1024000000 | 118000000 | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | us-east-1 |  |  |
| 2025-08-22 09:41:09.585 | 2025-08-22 09:41:11.680 | c9cc2b36-5184-4372-9999-959005466024 | 3496.99 | 3497 | 982.77 | 1024000000 | 119000000 | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | us-east-1 |  |  |
| 2025-08-22 09:46:35.004 | 2025-08-22 09:46:41.649 | 03a4b546-b53c-4026-8d9e-5464940d06d3 | 2378.47 | 2379 |  | 1024000000 | 120000000 | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | us-east-1 |  |  |
| 2025-08-22 09:46:35.946 | 2025-08-22 09:46:41.697 | 4ac70f93-82da-4274-9a86-f63e639c1819 | 3270.25 | 3271 |  | 1024000000 | 120000000 | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | us-east-1 |  |  |
| 2025-08-22 09:49:18.660 | 2025-08-22 09:49:24.811 | 98e42fe2-0885-47e5-89df-eb0f77fe8d37 | 2874.28 | 2875 |  | 1024000000 | 120000000 | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | us-east-1 |  |  |
| 2025-08-22 09:49:19.812 | 2025-08-22 09:49:25.453 | 69ab5d93-39c7-4bf1-933f-5871ca56923d | 3381.14 | 3382 |  | 1024000000 | 120000000 | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | us-east-1 |  |  |

