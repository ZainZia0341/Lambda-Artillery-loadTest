# Bedrock Invocations (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: bedrock-cloudwatch  
start-time: 2025-08-18T16:09:54Z  
end-time: 2025-08-18T17:11:12Z  
query-string:
`$nlfields @timestamp, @message, requestId
| sort @timestamp desc
| limit 50
`$nl---
**No data found for this query**

