#!/bin/bash

# Artillery Load Test with Log Collection - Bash Version
# Usage: ./run-load-and-collect-enhanced.sh

# Default parameters
REGION="${REGION:-us-east-1}"
PROFILE="${PROFILE:-default}"
YAML="${YAML:-./artillery.yml}"
NDJSON="${NDJSON:-./lambda-test.ndjson}"
LAMBDA_LOG_GROUP="${LAMBDA_LOG_GROUP:-/aws/lambda/ie-staging-claudeInvoker}"
BEDROCK_LOG_GROUP="${BEDROCK_LOG_GROUP:-bedrock-cloudwatch}"
TIME_BUFFER_MINUTES="${TIME_BUFFER_MINUTES:-30}"
INGESTION_DELAY_SECONDS="${INGESTION_DELAY_SECONDS:-60}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Disable AWS pager
export AWS_PAGER=""

# Function to ensure directory exists
ensure_dir() {
    mkdir -p "$1"
}

# Convert DateTime to Unix milliseconds
to_unix_milliseconds() {
    date -d "$1" +%s%3N
}

# Convert Unix milliseconds to DateTime
from_unix_milliseconds() {
    date -d "@$(echo "$1/1000" | bc -l)" '+%Y-%m-%d %H:%M:%S'
}

# Test if log group exists
test_log_group_exists() {
    local log_group=$1
    echo -e "${GRAY}  Checking log group: $log_group${NC}"
    
    result=$(aws --region "$REGION" --profile "$PROFILE" logs describe-log-groups \
        --log-group-name-prefix "$log_group" 2>&1)
    
    if echo "$result" | jq -e ".logGroups[] | select(.logGroupName == \"$log_group\")" > /dev/null 2>&1; then
        echo -e "${GREEN}[OK] Log group found: $log_group${NC}"
        return 0
    else
        echo -e "${RED}[MISS] Log group NOT found: $log_group${NC}"
        return 1
    fi
}

# Get log events using filter-log-events
get_log_events() {
    local log_group=$1
    local start_time=$2
    local end_time=$3
    local label=$4
    
    local start_ms=$(to_unix_milliseconds "$start_time")
    local end_ms=$(to_unix_milliseconds "$end_time")
    
    echo -e "${CYAN}[QUERY] $label group: $log_group${NC}"
    echo -e "${GRAY}         UTC range: $start_time → $end_time${NC}"
    echo -e "${GRAY}         Epoch ms: $start_ms → $end_ms${NC}"
    
    # REMOVED --max-items to avoid pagination issues
    result=$(aws logs filter-log-events \
        --log-group-name "$log_group" \
        --start-time "$start_ms" \
        --end-time "$end_ms" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --output json 2>&1)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERR] AWS CLI failed: $result${NC}"
        echo '{"events":[]}'
        return 1
    fi
    
    event_count=$(echo "$result" | jq '.events | length' 2>/dev/null || echo "0")
    if [ "$event_count" -gt 0 ]; then
        echo -e "${GREEN}         Found $event_count log events${NC}"
        echo "$result"
    else
        echo -e "${YELLOW}         No events found${NC}"
        echo '{"events":[]}'
    fi
}

# Parse Lambda REPORT message
parse_lambda_report() {
    local message=$1
    local timestamp=$2
    local ingestion_time=$3
    local log_stream=$4
    
    local request_id=$(echo "$message" | grep -oP 'REPORT RequestId:\s+\K[a-f0-9-]+' || echo "")
    local duration=$(echo "$message" | grep -oP 'Duration:\s+\K[\d.]+' || echo "null")
    local billed_duration=$(echo "$message" | grep -oP 'Billed Duration:\s+\K\d+' || echo "null")
    local init_duration=$(echo "$message" | grep -oP 'Init Duration:\s+\K[\d.]+' || echo "null")
    local memory_size=$(echo "$message" | grep -oP 'Memory Size:\s+\K\d+' || echo "0")
    local max_memory=$(echo "$message" | grep -oP 'Max Memory Used:\s+\K\d+' || echo "0")
    
    # Convert MB to bytes
    memory_size=$((memory_size * 1000000))
    max_memory=$((max_memory * 1000000))
    
    # Extract X-Ray trace IDs if present
    local xray_trace=""
    local xray_segment=""
    if [[ "$log_stream" =~ \[([a-f0-9-]+)\]([a-f0-9]+) ]]; then
        xray_trace="1-${BASH_REMATCH[1]:0:8}-${BASH_REMATCH[1]:8}"
        xray_segment="${BASH_REMATCH[2]}"
    fi
    
    cat <<EOF
{
    "@timestamp": "$timestamp",
    "@ingestionTime": "$ingestion_time",
    "@requestId": "$request_id",
    "@duration": $duration,
    "@billedDuration": $billed_duration,
    "@initDuration": $init_duration,
    "@memorySize": $memory_size,
    "@maxMemoryUsed": $max_memory,
    "@entity.KeyAttributes.Name": "ie-staging-claudeInvoker",
    "@entity.Attributes.Lambda.Function": "ie-staging-claudeInvoker",
    "@entity.Attributes.PlatformType": "AWS::Lambda",
    "@aws.account": "663981805246",
    "@aws.region": "$REGION",
    "@xrayTraceId": "$xray_trace",
    "@xraySegmentId": "$xray_segment",
    "@logStreamName": "$log_stream",
    "@message": "$message"
}
EOF
}

# Write CloudWatch Insights formatted markdown
write_cloudwatch_insights_markdown() {
    local outfile=$1
    local title=$2
    local region=$3
    local log_group=$4
    local start_time=$5
    local end_time=$6
    local data_file=$7
    local query_string=$8
    
    cat > "$outfile" <<EOF
# $title

**CloudWatch Logs Insights**  
region: $region  
log-group-names: $log_group  
start-time: $start_time  
end-time: $end_time  
query-string:
\`\`\`
$query_string
\`\`\`
---

EOF
    
    if [ -s "$data_file" ] && [ "$(jq 'length' "$data_file")" -gt 0 ]; then
        echo "| @timestamp | @requestId | @duration | @billedDuration | @memorySize | @maxMemoryUsed |" >> "$outfile"
        echo "| --- | --- | --- | --- | --- | --- |" >> "$outfile"
        
        jq -r '.[] | "| \(.["@timestamp"]) | \(.["@requestId"]) | \(.["@duration"]) | \(.["@billedDuration"]) | \(.["@memorySize"]) | \(.["@maxMemoryUsed"]) |"' "$data_file" >> "$outfile" 2>/dev/null || true
    else
        echo "**No data found for this query**" >> "$outfile"
    fi
}

# Main execution
echo ""
echo -e "${CYAN}========================================"
echo " ARTILLERY LOAD TEST WITH LOG COLLECTION"
echo -e "========================================${NC}"

# Create timestamped output folder
STAMP=$(date '+%Y-%m-%d_%H-%M-%S')Z
BASE_OUT="../monitoring-logs/${STAMP}"
ensure_dir "$BASE_OUT"

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

if test_log_group_exists "$LAMBDA_LOG_GROUP"; then
    lambda_exists=true
fi

if test_log_group_exists "$BEDROCK_LOG_GROUP"; then
    bedrock_exists=true
fi

if [ "$lambda_exists" = false ] && [ "$bedrock_exists" = false ]; then
    echo ""
    echo -e "${RED}[CRITICAL] Both log groups are missing.${NC}"
    echo -e "${YELLOW}Do you want to continue anyway? (y/N): ${NC}"
    read -r response
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo -e "${YELLOW}Exiting...${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}Press any key to continue with the test...${NC}"
read -n 1 -s -r

# Record test start time
echo -e "\n${YELLOW}STEP 1: Recording test start time...${NC}"
TEST_START=$(date -u '+%Y-%m-%d %H:%M:%S')
echo -e "${GREEN}Test started at: $TEST_START UTC${NC}"

# Run Artillery
echo -e "\n${YELLOW}STEP 2: Running Artillery load test...${NC}"
export REPORT_FILE="$NDJSON_OUT"
artillery run --output "$ARTILLERY_OUT" "$YAML"
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}[WARN] Artillery exited with non-zero code${NC}"
fi
TEST_END=$(date -u '+%Y-%m-%d %H:%M:%S')
echo -e "${GREEN}Test ended at: $TEST_END UTC${NC}"

# Process Artillery results
echo -e "\n${YELLOW}STEP 3: Processing Artillery results...${NC}"
if [ -f "$NDJSON_OUT" ]; then
    # Convert NDJSON to pretty JSON
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

# Set query window with buffer
echo -e "\n${YELLOW}STEP 5: Setting query time window...${NC}"
# Fix date arithmetic for Linux date command
START_Q=$(date -u -d "$TEST_START UTC -$TIME_BUFFER_MINUTES minutes" '+%Y-%m-%d %H:%M:%S')
END_Q=$(date -u -d "now +$TIME_BUFFER_MINUTES minutes" '+%Y-%m-%d %H:%M:%S')
echo -e "${GREEN}Query window: $START_Q to $END_Q UTC${NC}"

# Query Lambda logs
echo -e "\n${YELLOW}STEP 6: Querying and parsing Lambda logs...${NC}"

LAMBDA_QUERY_STRING="fields 
  @timestamp,
  @ingestionTime,
  @requestId,
  @duration,
  @billedDuration,
  @initDuration,
  @memorySize,
  @maxMemoryUsed
| filter @message like /^REPORT/
| sort @timestamp desc
| limit 100"

if [ "$lambda_exists" = true ]; then
    RAW_EVENTS=$(get_log_events "$LAMBDA_LOG_GROUP" "$START_Q" "$END_Q" "Lambda")
    
    # Check if RAW_EVENTS contains valid JSON
    if echo "$RAW_EVENTS" | jq empty 2>/dev/null; then
        # Parse REPORT events
        echo "$RAW_EVENTS" | jq -r '.events[] | select(.message | contains("REPORT RequestId")) | 
            "\(.timestamp)|\(.ingestionTime)|\(.message)|\(.logStreamName)"' 2>/dev/null | \
        while IFS='|' read -r ts ing_ts msg stream; do
            timestamp=$(from_unix_milliseconds "$ts")
            ingestion_time=$(from_unix_milliseconds "$ing_ts")
            parse_lambda_report "$msg" "$timestamp" "$ingestion_time" "$stream"
        done | jq -s '.' > "$LAMBDA_JSON_OUT"
        
        REPORT_COUNT=$(jq 'length' "$LAMBDA_JSON_OUT" 2>/dev/null || echo "0")
    else
        echo "[]" > "$LAMBDA_JSON_OUT"
        REPORT_COUNT=0
    fi
    
    echo -e "${GREEN}[SUCCESS] Lambda: $REPORT_COUNT REPORT entries found${NC}"
    
    # Generate markdown
    write_cloudwatch_insights_markdown "$LAMBDA_MD_OUT" \
        "Lambda Logs (CloudWatch Logs Insights)" "$REGION" "$LAMBDA_LOG_GROUP" \
        "$START_Q" "$END_Q" "$LAMBDA_JSON_OUT" "$LAMBDA_QUERY_STRING"
    
    # Extract metrics summary
    if [ "$REPORT_COUNT" -gt 0 ]; then
        AVG_DURATION=$(jq '[.[] | select(.["@duration"] != null) | .["@duration"]] | add/length' "$LAMBDA_JSON_OUT")
        MAX_DURATION=$(jq '[.[] | .["@duration"]] | max' "$LAMBDA_JSON_OUT")
        MIN_DURATION=$(jq '[.[] | select(.["@duration"] != null) | .["@duration"]] | min' "$LAMBDA_JSON_OUT")
        
        echo -e "\n  ${CYAN}Lambda Performance Summary:${NC}"
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
else
    echo "Log group not found: $LAMBDA_LOG_GROUP" > "$LAMBDA_MD_OUT"
    echo "[]" > "$LAMBDA_JSON_OUT"
    echo -e "${YELLOW}[SKIP] Lambda log group not found${NC}"
fi

# Query Bedrock logs
echo -e "\n${YELLOW}STEP 7: Querying and parsing Bedrock logs...${NC}"

BEDROCK_QUERY_STRING="fields
  @timestamp,
  @ingestionTime,
  requestId,
  timestamp as invocationTime,
  input.inputTokenCount,
  output.outputTokenCount,
  output.outputBodyJson.usage.input_tokens as usageInputTokens,
  output.outputBodyJson.usage.output_tokens as usageOutputTokens
| sort @timestamp desc
| limit 100"

if [ "$bedrock_exists" = true ]; then
    RAW_EVENTS=$(get_log_events "$BEDROCK_LOG_GROUP" "$START_Q" "$END_Q" "Bedrock")
    
    # Check if RAW_EVENTS contains valid JSON
    if echo "$RAW_EVENTS" | jq empty 2>/dev/null; then
        # Parse Bedrock events (expecting JSON format)
        echo "$RAW_EVENTS" | jq -r '.events[] | 
            {
                "@timestamp": (.timestamp | todate),
                "@ingestionTime": (.ingestionTime | todate),
                message: .message
            } + (.message | try fromjson // {})' 2>/dev/null | jq -s '.' > "$BEDROCK_JSON_OUT"
        
        EVENT_COUNT=$(jq 'length' "$BEDROCK_JSON_OUT" 2>/dev/null || echo "0")
    else
        echo "[]" > "$BEDROCK_JSON_OUT"
        EVENT_COUNT=0
    fi
    
    echo -e "${GREEN}[SUCCESS] Bedrock: $EVENT_COUNT invocation events found${NC}"
    
    # Generate markdown
    write_cloudwatch_insights_markdown "$BEDROCK_MD_OUT" \
        "Bedrock Logs (CloudWatch Logs Insights)" "$REGION" "$BEDROCK_LOG_GROUP" \
        "$START_Q" "$END_Q" "$BEDROCK_JSON_OUT" "$BEDROCK_QUERY_STRING"
    
    # Extract token metrics
    if [ "$EVENT_COUNT" -gt 0 ]; then
        # Calculate token statistics (handle potential null values)
        INPUT_TOKENS=$(jq '[.[] | .output.outputBodyJson.usage.input_tokens // 0] | add' "$BEDROCK_JSON_OUT")
        OUTPUT_TOKENS=$(jq '[.[] | .output.outputBodyJson.usage.output_tokens // 0] | add' "$BEDROCK_JSON_OUT")
        
        echo -e "\n  ${CYAN}Bedrock Token Summary:${NC}"
        echo -e "    ${GRAY}Invocations: $EVENT_COUNT${NC}"
        echo -e "    ${GRAY}Total Tokens: Input=$INPUT_TOKENS, Output=$OUTPUT_TOKENS${NC}"
        
        # Save stats
        cat > "$BASE_OUT/bedrock-token-stats.json" <<EOF
{
    "TotalInvocations": $EVENT_COUNT,
    "TotalInputTokens": $INPUT_TOKENS,
    "TotalOutputTokens": $OUTPUT_TOKENS
}
EOF
    fi
else
    echo "Log group not found: $BEDROCK_LOG_GROUP" > "$BEDROCK_MD_OUT"
    echo "[]" > "$BEDROCK_JSON_OUT"
    echo -e "${YELLOW}[SKIP] Bedrock log group not found${NC}"
fi

echo -e "\n${CYAN}========================================"
echo " TEST COMPLETE"
echo -e " Artifacts saved to: $BASE_OUT"
echo -e "========================================${NC}"

# End of script