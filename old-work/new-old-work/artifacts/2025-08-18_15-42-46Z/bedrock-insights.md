# Bedrock Invocations (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: bedrock-cloudwatch  
start-time: 2025-08-18T15:13:04Z  
end-time: 2025-08-18T16:14:18Z  
query-string:
`$nlfields @timestamp, @message, requestId
| sort @timestamp desc
| limit 50
`$nl---
**No data found for this query**

