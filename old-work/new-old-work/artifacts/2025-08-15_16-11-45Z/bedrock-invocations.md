# Bedrock Invocations (Flat)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: bedrock-cloudwatch  
start-time: 2025-08-15T16:02:02Z  
end-time: 2025-08-15T16:27:24Z  
query-string:
```
fields @timestamp, @ingestionTime, @log, @logStream, @message
| sort @timestamp desc
| limit 200
```
---
**No data found for this query**

