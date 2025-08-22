# Lambda Logs (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-15T17:25:40Z  
end-time: 2025-08-15T17:46:53Z  
query-string:
`$nlfields @timestamp, @message, @requestId, @type
| filter @message like /REPORT/ or @message like /START/ or @message like /END/ or @message like /ERROR/
| sort @timestamp desc
| limit 100
`$nl---
| @timestamp | @message | @requestId | @type |
| --- | --- | --- | --- |
| 2025-08-15 12:44:57.964 | REPORT RequestId: d4bb972a-523d-435f-ba6f-92950f76ad55	Duration: 3497.80 ms	Billed Duration: 3498 ms	Memory Size: 1024 MB	Max Memory Used: 119 MB	Init Duration: 986.19 ms	  | d4bb972a-523d-435f-ba6f-92950f76ad55 | REPORT |
| 2025-08-15 12:44:57.963 | END RequestId: d4bb972a-523d-435f-ba6f-92950f76ad55  | d4bb972a-523d-435f-ba6f-92950f76ad55 | END |
| 2025-08-15 12:44:57.847 | END RequestId: 60728812-66c3-4472-87f6-d67e98df9e2a  | 60728812-66c3-4472-87f6-d67e98df9e2a | END |
| 2025-08-15 12:44:57.847 | REPORT RequestId: 60728812-66c3-4472-87f6-d67e98df9e2a	Duration: 3392.76 ms	Billed Duration: 3393 ms	Memory Size: 1024 MB	Max Memory Used: 118 MB	Init Duration: 973.37 ms	  | 60728812-66c3-4472-87f6-d67e98df9e2a | REPORT |
| 2025-08-15 12:44:54.465 | START RequestId: d4bb972a-523d-435f-ba6f-92950f76ad55 Version: $LATEST  | d4bb972a-523d-435f-ba6f-92950f76ad55 | START |
| 2025-08-15 12:44:54.453 | START RequestId: 60728812-66c3-4472-87f6-d67e98df9e2a Version: $LATEST  | 60728812-66c3-4472-87f6-d67e98df9e2a | START |
| 2025-08-15 12:44:53.477 | INIT_START Runtime Version: nodejs:18.v80	Runtime Version ARN: arn:aws:lambda:us-east-1::runtime:eb463f0483e181b8fc1d514ec52ca261540b73dae25e5e0077f2656d17347da5  |  |  |
| 2025-08-15 12:44:53.475 | INIT_START Runtime Version: nodejs:18.v80	Runtime Version ARN: arn:aws:lambda:us-east-1::runtime:eb463f0483e181b8fc1d514ec52ca261540b73dae25e5e0077f2656d17347da5  |  |  |

