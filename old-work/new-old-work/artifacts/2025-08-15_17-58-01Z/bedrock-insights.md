# Bedrock Invocations (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: bedrock-cloudwatch  
start-time: 2025-08-15T17:48:09Z  
end-time: 2025-08-15T18:09:21Z  
query-string:
`$nlfields @timestamp, @message, requestId
| sort @timestamp desc
| limit 10
`$nl---
**No data found for this query**

