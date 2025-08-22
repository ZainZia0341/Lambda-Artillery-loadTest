# Lambda Logs (CloudWatch Logs Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-18T17:06:29Z  
end-time: 2025-08-18T18:07:41Z  
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
| 2025-08-18 17:20:48.391 | 2025-08-18 17:20:52.441 | 8ca81024-28c6-4e98-8c38-940817944cc8 | 3638.64 | 3639 | 1068.21 | 1024000000 | 119000000 | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | us-east-1 |  |  |
| 2025-08-18 17:20:48.401 | 2025-08-18 17:20:57.395 | cc89a74e-1d50-4375-b7b1-e6ae20e1e867 | 3738.74 | 3739 | 984.75 | 1024000000 | 118000000 | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | us-east-1 |  |  |
| 2025-08-18 17:36:39.109 | 2025-08-18 17:36:45.427 | aa5b5f7e-75ff-4fe1-8f1a-84e7aba6e700 | 2662.27 | 2663 | 1038.78 | 1024000000 | 119000000 | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | us-east-1 |  |  |
| 2025-08-18 17:36:39.279 | 2025-08-18 17:36:44.267 | 01434c0a-7dbc-4ee0-ba97-5fc388812665 | 2880.01 | 2881 | 953.8 | 1024000000 | 118000000 | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | us-east-1 |  |  |

