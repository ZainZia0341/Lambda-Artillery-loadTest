# Lambda REPORT

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-15T15:59:10Z  
end-time: 2025-08-15T16:20:25Z  
query-string:
```
fields @timestamp, @message, @logStream, @requestId
| sort @timestamp desc
| limit 50
```
---
**No data found for this query**

