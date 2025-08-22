# Lambda REPORT

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-15T15:36:32Z  
end-time: 2025-08-15T15:57:49Z  
query-string:
```
fields @timestamp, @message, @logStream, @requestId
| sort @timestamp desc
| limit 50
```
---
**No data found for this query**

