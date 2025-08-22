# AWS Load Testing & Log Collection Project

This project is a complete performance testing and monitoring solution designed to run load tests against AWS Lambda functions and automatically collect corresponding performance logs from AWS CloudWatch.

## Project Overview

The system consists of three main components that work together:

1. **Load Test Orchestrator Script** (`run-load-and-collect.ps1` for Windows / `run-load-and-collect-WORKING.sh` for Linux)
   - Orchestrates the entire testing process
   - Runs Artillery load tests
   - Collects and formats CloudWatch logs
   - Generates performance reports

2. **Artillery Configuration** (`artillery.yml`)
   - Defines test scenarios and load profiles
   - Configures target endpoints
   - Sets up custom telemetry processing

3. **Request Telemetry Processor** (`request-telemetry-processor.js`)
   - Captures detailed request/response information
   - Logs performance metrics in NDJSON format
   - Provides real-time visual feedback

## Prerequisites

### Common Requirements
- AWS CLI configured with appropriate credentials
- Artillery load testing tool (`npm install -g artillery`)
- Access to AWS CloudWatch logs
- Target Lambda function deployed

### Windows-Specific Requirements
- PowerShell 5.1 or higher
- Windows Terminal (recommended) or PowerShell ISE

### Linux/WSL Requirements
- Bash shell
- `jq` for JSON processing (`sudo apt-get install jq`)
- `bc` for calculations (`sudo apt-get install bc`)

---

## Windows Installation & Usage

### Installation

1. **Install Artillery globally:**
   ```powershell
   npm install -g artillery
   ```

2. **Configure AWS CLI:**
   ```powershell
   aws configure
   ```
   Enter your AWS Access Key, Secret Key, Region, and output format.

3. **Clone or download the project files** to your local machine.

### Running the Load Test

1. **Navigate to the project directory:**
   ```powershell
   cd C:\path\to\0301-functions\serverless\functions\claudeInvoker\artillery-load-testing
   ```

2. **Run the PowerShell script with default parameters:**
   ```powershell
   .\run-load-and-collect.ps1
   ```

3. **Or run with custom parameters:**
   ```powershell
   .\run-load-and-collect.ps1 `
     -Region us-east-1 `
     -Profile default `
     -Yaml .\artillery.yml `
     -Ndjson .\lambda-test.ndjson `
     -LambdaLogGroup "/aws/lambda/ie-staging-claudeInvoker" `
     -BedrockLogGroup "bedrock-cloudwatch" `
     -TimeBufferMinutes 30 `
     -IngestionDelaySeconds 60
   ```

### Windows Script Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Region` | us-east-1 | AWS region |
| `-Profile` | default | AWS CLI profile |
| `-Yaml` | .\artillery.yml | Artillery config file |
| `-Ndjson` | .\lambda-test.ndjson | Output file for request data |
| `-LambdaLogGroup` | /aws/lambda/ie-staging-claudeInvoker | Lambda CloudWatch log group |
| `-BedrockLogGroup` | bedrock-cloudwatch | Bedrock CloudWatch log group |
| `-TimeBufferMinutes` | 30 | Time buffer for log queries |
| `-IngestionDelaySeconds` | 60 | Wait time for log ingestion |

---

## Linux/WSL Installation & Usage

### Installation

1. **Update package list and install dependencies:**
   ```bash
   sudo apt-get update
   sudo apt-get install -y jq bc curl unzip
   ```

2. **Install Node.js and npm (if not already installed):**
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

3. **Install Artillery globally:**
   ```bash
   sudo npm install -g artillery
   ```

4. **Install AWS CLI v2:**
   ```bash
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   rm -rf awscliv2.zip aws/
   ```

5. **Configure AWS CLI:**
   ```bash
   aws configure
   ```

### Running the Load Test

1. **Navigate to the project directory:**
   ```bash
   cd /home/username/0301-functions/serverless/functions/claudeInvoker/artillery-load-testing
   ```

2. **Make the script executable:**
   ```bash
   chmod +x run-load-and-collect-WORKING.sh
   ```

3. **Run with default parameters:**
   ```bash
   ./run-load-and-collect-WORKING.sh
   ```

4. **Or run with custom parameters using environment variables:**
   ```bash
   REGION=us-east-1 \
   PROFILE=default \
   YAML=./artillery.yml \
   LAMBDA_LOG_GROUP=/aws/lambda/ie-staging-claudeInvoker \
   BEDROCK_LOG_GROUP=bedrock-cloudwatch \
   INGESTION_DELAY_SECONDS=90 \
   ./run-load-and-collect-WORKING.sh
   ```

### Linux Script Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REGION` | us-east-1 | AWS region |
| `PROFILE` | default | AWS CLI profile |
| `YAML` | ./artillery.yml | Artillery config file |
| `NDJSON` | ./lambda-test.ndjson | Output file for request data |
| `LAMBDA_LOG_GROUP` | /aws/lambda/ie-staging-claudeInvoker | Lambda CloudWatch log group |
| `BEDROCK_LOG_GROUP` | bedrock-cloudwatch | Bedrock CloudWatch log group |
| `INGESTION_DELAY_SECONDS` | 90 | Wait time for log ingestion |

---

## Output Files

After running the test, the following files are generated in a timestamped directory under `../monitoring-logs/`:

| File | Description |
|------|-------------|
| `artillery-metrics.json` | High-level Artillery performance metrics |
| `lambda-test.ndjson` | Raw per-request data in NDJSON format |
| `report.json` | Formatted request/response details |
| `lambda-insights.json` | Parsed Lambda REPORT events |
| `lambda-insights.md` | Lambda logs in CloudWatch Insights format |
| `bedrock-insights.json` | Parsed Bedrock invocation logs |
| `bedrock-insights.md` | Bedrock logs in CloudWatch Insights format |
| `lambda-performance-stats.json` | Lambda performance summary |
| `bedrock-token-stats.json` | Bedrock token usage summary |
| `summary.txt` | Overall test summary |

## Artillery Configuration (artillery.yml)

The `artillery.yml` file defines your load test scenario:

```yaml
config:
  target: "https://your-lambda-url.execute-api.region.amazonaws.com"
  processor: "./request-telemetry-processor.js"
  phases:
    - name: "test-phase"
      duration: 1        # Test duration in seconds
      arrivalRate: 2      # Requests per second

scenarios:
  - name: "lambda-claude-test"
    flow:
      - post:
          url: "/invoke"
          beforeRequest: "markStart"
          afterResponse: "logRequest"
          json:
            question: "Your test question"
            evaluationPrompt: "Your evaluation criteria"
            userAnswer: "Test answer"
```

## Request Telemetry Processor

The `request-telemetry-processor.js` captures detailed metrics for each request:

- Request/response timestamps
- HTTP status codes
- Response times
- Request/response headers
- Request/response bodies
- AWS request IDs for correlation

Visual indicators in console output:
- 🟢 Fast response (< 1000ms)
- 🟡 Medium response (1000-3000ms)
- 🔴 Slow response (> 3000ms)

## Troubleshooting

### Common Issues

1. **No logs found after test:**
   - Increase `INGESTION_DELAY_SECONDS` to 120 or more
   - Verify log group names are correct
   - Check AWS CLI credentials and permissions

2. **Script fails with permission errors (Linux):**
   ```bash
   chmod +x run-load-and-collect-WORKING.sh
   chmod +x request-telemetry-processor.js
   ```

3. **AWS CLI not found (Linux/WSL):**
   - Ensure AWS CLI v2 is installed
   - Check PATH: `echo $PATH`
   - Verify installation: `aws --version`

4. **JQ parsing errors (Linux):**
   - Install/update jq: `sudo apt-get install --upgrade jq`
   - Verify JSON format of log messages

### Debug Mode

For Linux/WSL, you can enable debug output:
```bash
set -x  # Add this at the beginning of the script
```

For Windows PowerShell:
```powershell
$VerbosePreference = "Continue"
$DebugPreference = "Continue"
```

3. **Run with default parameters:**
   ```bash
   ./run-load-and-collect-WORKING.sh
   ```

4. **Or run with custom parameters using environment variables:**
   ```bash
   REGION=us-east-1 \
   PROFILE=default \
   YAML=./artillery.yml \
   LAMBDA_LOG_GROUP=/aws/lambda/ie-staging-claudeInvoker \
   BEDROCK_LOG_GROUP=bedrock-cloudwatch \
   INGESTION_DELAY_SECONDS=90 \
   ./run-load-and-collect-WORKING.sh
   ```