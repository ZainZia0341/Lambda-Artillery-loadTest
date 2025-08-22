# Lambda Logs (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-18T15:53:01Z  
end-time: 2025-08-18T16:58:15Z  
query-string:
`$nlfields @timestamp, @message, @requestId, @type
| filter @message like /REPORT/ or @message like /START/ or @message like /END/ or @message like /ERROR/
| sort @timestamp desc
| limit 100
`$nl---
**No data found for this query**

