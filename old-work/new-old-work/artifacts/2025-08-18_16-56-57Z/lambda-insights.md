# Lambda Logs (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-18T16:27:06Z  
end-time: 2025-08-18T17:29:20Z  
query-string:
`$nlfields @timestamp, @message, @requestId, @type
| filter @message like /REPORT/ or @message like /START/ or @message like /END/
| sort @timestamp desc
| limit 100
`$nl---
**No data found for this query**

