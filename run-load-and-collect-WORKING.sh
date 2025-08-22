#!/bin/bash

# WORKING Artillery Load Test with Log Collection
# Based on the successful simple-collect-all-logs.sh

# Default parameters
REGION="${REGION:-us-east-1}"
PROFILE="${PROFILE:-default}"
YAML="${YAML:-./artillery.yml}"
NDJSON="${NDJSON:-./lambda-test.ndjson}"
LAMBDA_LOG_GROUP="${LAMBDA_LOG_GROUP:-/aws/lambda/ie-staging-claudeInvoker}"
BEDROCK_LOG_GROUP="${BEDROCK_LOG_GROUP:-bedrock-cloudwatch}"
INGESTION_DELAY_SECONDS="${INGESTION_DELAY_SECONDS:-90}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Disable AWS pager
export AWS_PAGER=""

echo ""
echo -e "${CYAN}========================================"
echo " ARTILLERY LOAD TEST WITH LOG COLLECTION"
echo -e "========================================${NC}"

# Create timestamped output folder
STAMP=$(date '+%Y-%m-%d_%H-%M-%S')Z
BASE_OUT="../monitoring-logs/${STAMP}"
mkdir -p "$BASE_OUT"

ARTILLERY_OUT="$BASE_OUT/artillery-metrics.json"
NDJSON_OUT="$BASE_OUT/$(basename "$NDJSON")"
PRETTY_JSON_OUT="$BASE_OUT/report.json"
LAMBDA_JSON_OUT="$BASE_OUT/lambda-insights.json"
BEDROCK_JSON_OUT="$BASE_OUT/bedrock-insights.json"
LAMBDA_MD_OUT="$BASE_OUT/lambda-insights.md"
BEDROCK_MD_OUT="$BASE_OUT/bedrock-insights.md"

# Verify log groups exist
echo -e "\n${YELLOW}STEP 0: Verifying log groups...${NC}"

lambda_exists=false
bedrock_exists=false

# Check Lambda log group
echo -e "${GRAY}  Checking log group: $LAMBDA_LOG_GROUP${NC}"
if aws logs describe-log-groups \
    --log-group-name-prefix "$LAMBDA_LOG_GROUP" \
    --region "$REGION" \
    --profile "$PROFILE" 2>&1 | \
    jq -e ".logGroups[] | select(.logGroupName == \"$LAMBDA_LOG_GROUP\")" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] Log group found: $LAMBDA_LOG_GROUP${NC}"
    lambda_exists=true
else
    echo -e "${RED}[MISS] Log group NOT found: $LAMBDA_LOG_GROUP${NC}"
fi

# Check Bedrock log group
echo -e "${GRAY}  Checking log group: $BEDROCK_LOG_GROUP${NC}"
if aws logs describe-log-groups \
    --log-group-name-prefix "$BEDROCK_LOG_GROUP" \
    --region "$REGION" \
    --profile "$PROFILE" 2>&1 | \
    jq -e ".logGroups[] | select(.logGroupName == \"$BEDROCK_LOG_GROUP\")" > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] Log group found: $BEDROCK_LOG_GROUP${NC}"
    bedrock_exists=true
else
    echo -e "${RED}[MISS] Log group NOT found: $BEDROCK_LOG_GROUP${NC}"
fi

if [ "$lambda_exists" = false ] && [ "$bedrock_exists" = false ]; then
    echo -e "\n${RED}[CRITICAL] Both log groups are missing.${NC}"
    echo -e "${YELLOW}Do you want to continue anyway? (y/N): ${NC}"
    read -r response
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo -e "${YELLOW}Exiting...${NC}"
        exit 1
    fi
fi

echo -e "\n${YELLOW}Press any key to continue with the test...${NC}"
read -n 1 -s -r

# Record test start time IN MILLISECONDS
echo -e "\n${YELLOW}STEP 1: Recording test start time...${NC}"
TEST_START_MS=$(date +%s%3N)
TEST_START_READABLE=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
echo -e "${GREEN}Test started at: $TEST_START_READABLE${NC}"

# Run Artillery
echo -e "\n${YELLOW}STEP 2: Running Artillery load test...${NC}"
export REPORT_FILE="$NDJSON_OUT"
artillery run --output "$ARTILLERY_OUT" "$YAML"
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}[WARN] Artillery exited with non-zero code${NC}"
fi

TEST_END_MS=$(date +%s%3N)
TEST_END_READABLE=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
echo -e "${GREEN}Test ended at: $TEST_END_READABLE${NC}"

# Process Artillery results
echo -e "\n${YELLOW}STEP 3: Processing Artillery results...${NC}"
if [ -f "$NDJSON_OUT" ]; then
    jq -s '.' "$NDJSON_OUT" > "$PRETTY_JSON_OUT"
    RECORD_COUNT=$(jq -s 'length' "$NDJSON_OUT")
    echo -e "${GREEN}[OK] $RECORD_COUNT per-request records -> $PRETTY_JSON_OUT${NC}"
else
    echo "[]" > "$PRETTY_JSON_OUT"
    echo -e "${YELLOW}[WARN] No NDJSON output found${NC}"
fi

# Wait for CloudWatch ingestion
echo -e "\n${YELLOW}STEP 4: Waiting for CloudWatch ingestion...${NC}"
echo -e "${CYAN}Waiting $INGESTION_DELAY_SECONDS seconds for CloudWatch log ingestion...${NC}"
for ((i=$INGESTION_DELAY_SECONDS; i>0; i-=10)); do
    echo -e "${GRAY}  $i seconds remaining...${NC}"
    sleep $((i < 10 ? i : 10))
done

# Set query window with buffer (using milliseconds directly)
echo -e "\n${YELLOW}STEP 5: Setting query time window...${NC}"
QUERY_START_MS=$((TEST_START_MS - 60000))  # 1 minute before test
QUERY_END_MS=$((TEST_END_MS + 120000))     # 2 minutes after test

# Convert milliseconds to readable format for display
START_Q_READABLE=$(date -d "@$((QUERY_START_MS/1000))" -u '+%Y-%m-%d %H:%M:%S')
END_Q_READABLE=$(date -d "@$((QUERY_END_MS/1000))" -u '+%Y-%m-%d %H:%M:%S')
echo -e "${GREEN}Query window: $START_Q_READABLE to $END_Q_READABLE UTC${NC}"

# Query Lambda logs
echo -e "\n${YELLOW}STEP 6: Querying and parsing Lambda logs...${NC}"

if [ "$lambda_exists" = true ]; then
    echo -e "${CYAN}[QUERY] Lambda group: $LAMBDA_LOG_GROUP${NC}"
    
    # Get ALL Lambda logs (no filtering, no max-items)
    RAW_RESULT=$(aws logs filter-log-events \
        --log-group-name "$LAMBDA_LOG_GROUP" \
        --start-time "$QUERY_START_MS" \
        --end-time "$QUERY_END_MS" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --output json 2>&1)
    
    if [ $? -eq 0 ]; then
        # Save raw events
        echo "$RAW_RESULT" > "$BASE_OUT/lambda-raw.json"
        
        EVENT_COUNT=$(echo "$RAW_RESULT" | jq '.events | length')
        echo -e "${GREEN}         Found $EVENT_COUNT total log events${NC}"
        
        # Extract and parse REPORT events
        echo "$RAW_RESULT" | jq '[.events[] | select(.message | contains("REPORT RequestId"))]' > "$LAMBDA_JSON_OUT"
        REPORT_COUNT=$(jq 'length' "$LAMBDA_JSON_OUT")
        
        echo -e "${GREEN}[SUCCESS] Lambda: $REPORT_COUNT REPORT entries found out of $EVENT_COUNT total events${NC}"
        
        # Generate markdown report
        cat > "$LAMBDA_MD_OUT" <<EOF
# Lambda Logs (CloudWatch Logs Insights)

**CloudWatch Logs Insights**  
region: $REGION  
log-group-names: $LAMBDA_LOG_GROUP  
start-time: -3600s  
end-time: 0s  
query-string:
\`\`\`
fields 
  @timestamp,
  @ingestionTime,
  @requestId,
  @duration,
  @billedDuration,
  @initDuration,
  @memorySize,
  @maxMemoryUsed,
  @entity.KeyAttributes.Name,
  @entity.Attributes.Lambda.Function,
  @entity.Attributes.PlatformType,
  @aws.account,
  @aws.region,
  @xrayTraceId,
  @xraySegmentId
| filter @message like /^REPORT/
| sort @timestamp desc
| limit 100
\`\`\`
---

| @timestamp | @ingestionTime | @requestId | @duration | @billedDuration | @initDuration | @memorySize | @maxMemoryUsed | @entity.KeyAttributes.Name | @entity.Attributes.Lambda.Function | @entity.Attributes.PlatformType | @aws.account | @aws.region | @xrayTraceId | @xraySegmentId |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
EOF
        
        # Parse REPORT messages and add to markdown with all fields
        if [ "$REPORT_COUNT" -gt 0 ]; then
            jq -r '.[] | 
                # Convert milliseconds to proper date format
                (.timestamp / 1000 | strftime("%Y-%m-%d %H:%M:%S.%3N")) as $ts |
                (.ingestionTime / 1000 | strftime("%Y-%m-%d %H:%M:%S.%3N")) as $ing_ts |
                
                # Extract fields from REPORT message
                (.message | capture("RequestId: (?<id>[^ \\t]+)") | .id // "") as $req_id |
                (.message | capture("Duration: (?<dur>[0-9.]+)") | .dur // "") as $duration |
                (.message | capture("Billed Duration: (?<bd>[0-9]+)") | .bd // "") as $billed |
                (.message | capture("Init Duration: (?<init>[0-9.]+)") | .init // "") as $init |
                (.message | capture("Memory Size: (?<ms>[0-9]+)") | .ms // "1024") as $mem_size_mb |
                (.message | capture("Max Memory Used: (?<mu>[0-9]+)") | .mu // "0") as $mem_used_mb |
                
                # Convert MB to bytes (multiply by 1000000)
                ($mem_size_mb | tonumber * 1000000 | tostring) as $mem_size |
                ($mem_used_mb | tonumber * 1000000 | tostring) as $mem_used |
                
                # Extract X-Ray trace IDs from log stream name if present
                (.logStreamName | capture("\\[(?<trace>[a-f0-9-]+)\\](?<seg>[a-f0-9]+)") // {}) as $xray |
                (if $xray.trace then "1-" + $xray.trace[0:8] + "-" + $xray.trace[8:] else "" end) as $trace_id |
                ($xray.seg // "") as $segment_id |
                
                "| \($ts) | \($ing_ts) | \($req_id) | \($duration) | \($billed) | \($init) | \($mem_size) | \($mem_used) | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | \(env.REGION // "us-east-1") | \($trace_id) | \($segment_id) |"
            ' "$LAMBDA_JSON_OUT" >> "$LAMBDA_MD_OUT" 2>/dev/null || \
            # Fallback if jq fails - simpler parsing
            jq -r '.[] | 
                "| " + (.timestamp | tostring | .[0:10] | tonumber | strftime("%Y-%m-%d %H:%M:%S")) + 
                " | " + (.ingestionTime | tostring | .[0:10] | tonumber | strftime("%Y-%m-%d %H:%M:%S")) +
                " | " + (.message | capture("RequestId: ([^ \\t]+)") | .[0] // "") +
                " | " + (.message | capture("Duration: ([0-9.]+)") | .[0] // "") +
                " | " + (.message | capture("Billed Duration: ([0-9]+)") | .[0] // "") +
                " | " + (.message | capture("Init Duration: ([0-9.]+)") | .[0] // "") +
                " | " + ((.message | capture("Memory Size: ([0-9]+)") | .[0] // "1024") | tonumber * 1000000 | tostring) +
                " | " + ((.message | capture("Max Memory Used: ([0-9]+)") | .[0] // "0") | tonumber * 1000000 | tostring) +
                " | ie-staging-claudeInvoker | ie-staging-claudeInvoker | AWS::Lambda | 663981805246 | us-east-1 |  |  |"
            ' "$LAMBDA_JSON_OUT" >> "$LAMBDA_MD_OUT"
            
            echo "---" >> "$LAMBDA_MD_OUT"
        else
            echo "No REPORT events found in the time window." >> "$LAMBDA_MD_OUT"
            echo "---" >> "$LAMBDA_MD_OUT"
        fi
        
        # Calculate performance summary
        if [ "$REPORT_COUNT" -gt 0 ]; then
            echo -e "\n  ${CYAN}Lambda Performance Summary:${NC}"
            
            # Extract durations
            DURATIONS=$(jq -r '.[] | .message | capture("Duration: (?<dur>[0-9.]+)") | .dur' "$LAMBDA_JSON_OUT" 2>/dev/null | grep -v null)
            
            if [ ! -z "$DURATIONS" ]; then
                AVG_DURATION=$(echo "$DURATIONS" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
                MAX_DURATION=$(echo "$DURATIONS" | sort -rn | head -1)
                MIN_DURATION=$(echo "$DURATIONS" | sort -n | head -1)
                
                echo -e "    ${GRAY}Invocations: $REPORT_COUNT${NC}"
                echo -e "    ${GRAY}Duration: Avg=${AVG_DURATION}ms, Min=${MIN_DURATION}ms, Max=${MAX_DURATION}ms${NC}"
                
                # Save stats
                cat > "$BASE_OUT/lambda-performance-stats.json" <<EOF
{
    "TotalInvocations": $REPORT_COUNT,
    "AverageDuration": $AVG_DURATION,
    "MaxDuration": $MAX_DURATION,
    "MinDuration": $MIN_DURATION
}
EOF
            fi
        fi
    else
        echo -e "${RED}[ERR] Failed to query Lambda logs${NC}"
        echo "[]" > "$LAMBDA_JSON_OUT"
        echo "Error querying logs" > "$LAMBDA_MD_OUT"
    fi
else
    echo "[]" > "$LAMBDA_JSON_OUT"
    echo "Log group not found: $LAMBDA_LOG_GROUP" > "$LAMBDA_MD_OUT"
    echo -e "${YELLOW}[SKIP] Lambda log group not found${NC}"
fi

# Query Bedrock logs
echo -e "\n${YELLOW}STEP 7: Querying and parsing Bedrock logs...${NC}"

if [ "$bedrock_exists" = true ]; then
    echo -e "${CYAN}[QUERY] Bedrock group: $BEDROCK_LOG_GROUP${NC}"
    
    # Get ALL Bedrock logs
    RAW_RESULT=$(aws logs filter-log-events \
        --log-group-name "$BEDROCK_LOG_GROUP" \
        --start-time "$QUERY_START_MS" \
        --end-time "$QUERY_END_MS" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --output json 2>&1)
    
    if [ $? -eq 0 ]; then
        # Save raw and processed
        echo "$RAW_RESULT" > "$BASE_OUT/bedrock-raw.json"
        cp "$BASE_OUT/bedrock-raw.json" "$BEDROCK_JSON_OUT"
        
        EVENT_COUNT=$(echo "$RAW_RESULT" | jq '.events | length')
        echo -e "${GREEN}[SUCCESS] Bedrock: $EVENT_COUNT invocation events found${NC}"
        
        # Generate markdown report
        cat > "$BEDROCK_MD_OUT" <<EOF
# Bedrock Logs (CloudWatch Logs Insights)

**CloudWatch Logs Insights**  
region: $REGION  
log-group-names: $BEDROCK_LOG_GROUP  
start-time: -3600s  
end-time: 0s  
query-string:
\`\`\`
fields
  @timestamp,
  @ingestionTime,
  requestId,
  @aws.account,
  @aws.region,
  timestamp as invocationTime,
  accountId,
  @message,
  inferenceRegion,
  input.inputTokenCount,
  input.inputBodyJson.anthropic_version as anthropicVersion,
  output.outputTokenCount,
  output.outputBodyJson.id as invocationId,
  output.outputBodyJson.model as outputModel,
  output.outputBodyJson.usage.input_tokens as usageInputTokens,
  output.outputBodyJson.usage.output_tokens as usageOutputTokens,
  output.outputBodyJson.usage.cache_creation_input_tokens as cacheCreateTokens,
  output.outputBodyJson.usage.cache_read_input_tokens as cacheReadTokens
| sort @timestamp desc
| limit 100
\`\`\`
---

| @timestamp | @ingestionTime | requestId | @aws.account | @aws.region | invocationTime | accountId | @message | inferenceRegion | input.inputTokenCount | anthropicVersion | output.outputTokenCount | invocationId | outputModel | usageInputTokens | usageOutputTokens | cacheCreateTokens | cacheReadTokens |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
EOF
        
        if [ "$EVENT_COUNT" -gt 0 ]; then
            # Parse Bedrock JSON logs and extract all fields
            jq -r '.events[] | 
                # Convert timestamps
                (.timestamp / 1000 | strftime("%Y-%m-%d %H:%M:%S.%3N")) as $ts |
                (.ingestionTime / 1000 | strftime("%Y-%m-%d %H:%M:%S.%3N")) as $ing_ts |
                
                # Parse the JSON message
                (.message | fromjson) as $msg |
                
                # Build the table row
                "| \($ts) | \($ing_ts) | \($msg.requestId // "") | \($msg.accountId // "663981805246") | \($msg.region // "us-east-1") | \($msg.timestamp // "") | \($msg.accountId // "") | " +
                (.message | gsub("\n"; " ") | .[0:200]) + "... | " +
                "\($msg.inferenceRegion // "") | \($msg.input.inputTokenCount // "") | \($msg.input.inputBodyJson.anthropic_version // "") | \($msg.output.outputTokenCount // "") | " +
                "\($msg.output.outputBodyJson.id // "") | \($msg.output.outputBodyJson.model // "") | " +
                "\($msg.output.outputBodyJson.usage.input_tokens // "") | \($msg.output.outputBodyJson.usage.output_tokens // "") | " +
                "\($msg.output.outputBodyJson.usage.cache_creation_input_tokens // "0") | \($msg.output.outputBodyJson.usage.cache_read_input_tokens // "0") |"
            ' "$BASE_OUT/bedrock-raw.json" >> "$BEDROCK_MD_OUT" 2>/dev/null || \
            # Fallback for simpler parsing if jq fails
            echo "| Data parsing error - see bedrock-raw.json for details |" >> "$BEDROCK_MD_OUT"
            
            echo "---" >> "$BEDROCK_MD_OUT"
        else
            echo "No events found in the time window." >> "$BEDROCK_MD_OUT"
            echo "---" >> "$BEDROCK_MD_OUT"
        fi
    else
        echo -e "${RED}[ERR] Failed to query Bedrock logs${NC}"
        echo "[]" > "$BEDROCK_JSON_OUT"
        echo "Error querying logs" > "$BEDROCK_MD_OUT"
    fi
else
    echo "[]" > "$BEDROCK_JSON_OUT"
    echo "Log group not found: $BEDROCK_LOG_GROUP" > "$BEDROCK_MD_OUT"
    echo -e "${YELLOW}[SKIP] Bedrock log group not found${NC}"
fi

# Create summary file
cat > "$BASE_OUT/summary.txt" <<EOF
Test Summary
============
Test Start: $TEST_START_READABLE
Test End: $TEST_END_READABLE
Query Window: $START_Q_READABLE to $END_Q_READABLE UTC

Lambda Events: $(jq '.events | length' "$BASE_OUT/lambda-raw.json" 2>/dev/null || echo "0")
Lambda REPORT Events: $(jq 'length' "$LAMBDA_JSON_OUT" 2>/dev/null || echo "0")
Bedrock Events: $(jq '.events | length' "$BEDROCK_JSON_OUT" 2>/dev/null || echo "0")

Files Generated:
$(ls -1 "$BASE_OUT")
EOF

echo ""
echo -e "${CYAN}========================================"
echo -e " ${GREEN}TEST COMPLETE${NC}"
echo -e " ${GREEN}Artifacts saved to: $BASE_OUT${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo "Files created:"
ls -la "$BASE_OUT"

# End of script