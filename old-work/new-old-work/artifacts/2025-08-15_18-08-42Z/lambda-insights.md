# Lambda Logs (Insights)

**CloudWatch Logs Insights**  
region: us-east-1  
log-group-names: /aws/lambda/ie-staging-claudeInvoker  
start-time: 2025-08-15T17:58:48Z  
end-time: 2025-08-15T18:20:03Z  
query-string:
`$nlfields @timestamp, @message, @requestId, @type
| filter @message like /REPORT/ or @message like /START/ or @message like /END/ or @message like /ERROR/
| sort @timestamp desc
| limit 100
`$nl---
| @timestamp | @message | @requestId | @type |
| --- | --- | --- | --- |
| 2025-08-15 13:17:24.627 | END RequestId: 91c92f73-37ae-4b1d-8b83-77f557113654  | 91c92f73-37ae-4b1d-8b83-77f557113654 | END |
| 2025-08-15 13:17:24.627 | REPORT RequestId: 91c92f73-37ae-4b1d-8b83-77f557113654	Duration: 3666.80 ms	Billed Duration: 3667 ms	Memory Size: 1024 MB	Max Memory Used: 119 MB	Init Duration: 960.07 ms	  | 91c92f73-37ae-4b1d-8b83-77f557113654 | REPORT |
| 2025-08-15 13:17:23.822 | END RequestId: 612ad94f-733f-4acf-a8b6-53e0eec679e6  | 612ad94f-733f-4acf-a8b6-53e0eec679e6 | END |
| 2025-08-15 13:17:23.822 | REPORT RequestId: 612ad94f-733f-4acf-a8b6-53e0eec679e6	Duration: 2858.27 ms	Billed Duration: 2859 ms	Memory Size: 1024 MB	Max Memory Used: 119 MB	Init Duration: 961.59 ms	  | 612ad94f-733f-4acf-a8b6-53e0eec679e6 | REPORT |
| 2025-08-15 13:17:20.963 | START RequestId: 612ad94f-733f-4acf-a8b6-53e0eec679e6 Version: $LATEST  | 612ad94f-733f-4acf-a8b6-53e0eec679e6 | START |
| 2025-08-15 13:17:20.960 | START RequestId: 91c92f73-37ae-4b1d-8b83-77f557113654 Version: $LATEST  | 91c92f73-37ae-4b1d-8b83-77f557113654 | START |
| 2025-08-15 13:17:19.997 | INIT_START Runtime Version: nodejs:18.v80	Runtime Version ARN: arn:aws:lambda:us-east-1::runtime:eb463f0483e181b8fc1d514ec52ca261540b73dae25e5e0077f2656d17347da5  |  |  |
| 2025-08-15 13:17:19.995 | INIT_START Runtime Version: nodejs:18.v80	Runtime Version ARN: arn:aws:lambda:us-east-1::runtime:eb463f0483e181b8fc1d514ec52ca261540b73dae25e5e0077f2656d17347da5  |  |  |

