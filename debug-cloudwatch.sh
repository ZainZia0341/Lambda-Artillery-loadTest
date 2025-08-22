#!/bin/bash

# Simplified script that just collects ALL logs during and after your test
# No filtering, just raw collection

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

REGION="${REGION:-us-east-1}"
PROFILE="${PROFILE:-default}"
YAML="${YAML:-./artillery.yml}"

echo -e "${CYAN}================================${NC}"
echo -e "${CYAN}SIMPLE LOG COLLECTOR${NC}"
echo -e "${CYAN}================================${NC}"
echo ""

# Create output directory
STAMP=$(date '+%Y-%m-%d_%H-%M-%S')
OUT_DIR="../monitoring-logs/${STAMP}-simple"
mkdir -p "$OUT_DIR"

# Record start time
echo -e "${YELLOW}Starting Artillery test...${NC}"
TEST_START_MS=$(date +%s%3N)
TEST_START_READABLE=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
echo "Test start: $TEST_START_READABLE"
echo ""

# Run Artillery
artillery run "$YAML" --output "$OUT_DIR/artillery.json"

# Record end time
TEST_END_MS=$(date +%s%3N)
TEST_END_READABLE=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
echo ""
echo "Test end: $TEST_END_READABLE"

# Wait a bit for logs
echo -e "${YELLOW}Waiting 90 seconds for CloudWatch logs...${NC}"
sleep 90

# Add buffer to time window
QUERY_START_MS=$((TEST_START_MS - 60000))  # 1 minute before
QUERY_END_MS=$((TEST_END_MS + 120000))     # 2 minutes after

echo ""
echo -e "${CYAN}Collecting Lambda logs...${NC}"
echo "Time window: $(date -d @$((QUERY_START_MS/1000)) -u '+%Y-%m-%d %H:%M:%S') to $(date -d @$((QUERY_END_MS/1000)) -u '+%Y-%m-%d %H:%M:%S') UTC"

# Get ALL Lambda logs (no filtering)
aws logs filter-log-events \
    --log-group-name "/aws/lambda/ie-staging-claudeInvoker" \
    --start-time "$QUERY_START_MS" \
    --end-time "$QUERY_END_MS" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --output json > "$OUT_DIR/lambda-raw.json" 2>&1

if [ $? -eq 0 ]; then
    COUNT=$(jq '.events | length' "$OUT_DIR/lambda-raw.json")
    echo -e "${GREEN}✓ Collected $COUNT Lambda log events${NC}"
    
    # Extract just REPORT lines
    jq '[.events[] | select(.message | contains("REPORT"))]' "$OUT_DIR/lambda-raw.json" > "$OUT_DIR/lambda-reports.json"
    REPORT_COUNT=$(jq 'length' "$OUT_DIR/lambda-reports.json")
    echo "  Including $REPORT_COUNT REPORT entries"
    
    # Create simple summary
    echo "Lambda Log Summary" > "$OUT_DIR/summary.txt"
    echo "==================" >> "$OUT_DIR/summary.txt"
    echo "Total events: $COUNT" >> "$OUT_DIR/summary.txt"
    echo "REPORT events: $REPORT_COUNT" >> "$OUT_DIR/summary.txt"
    echo "" >> "$OUT_DIR/summary.txt"
    echo "Sample messages:" >> "$OUT_DIR/summary.txt"
    jq -r '.events[0:5] | .[] | .message' "$OUT_DIR/lambda-raw.json" >> "$OUT_DIR/summary.txt" 2>/dev/null
    
else
    echo -e "${RED}✗ Failed to collect Lambda logs${NC}"
    cat "$OUT_DIR/lambda-raw.json"
fi

echo ""
echo -e "${CYAN}Collecting Bedrock logs...${NC}"

# Get ALL Bedrock logs
aws logs filter-log-events \
    --log-group-name "bedrock-cloudwatch" \
    --start-time "$QUERY_START_MS" \
    --end-time "$QUERY_END_MS" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --output json > "$OUT_DIR/bedrock-raw.json" 2>&1

if [ $? -eq 0 ]; then
    COUNT=$(jq '.events | length' "$OUT_DIR/bedrock-raw.json")
    echo -e "${GREEN}✓ Collected $COUNT Bedrock log events${NC}"
else
    echo -e "${RED}✗ Failed to collect Bedrock logs${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}COMPLETE!${NC}"
echo -e "${GREEN}Results in: $OUT_DIR${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Files created:"
ls -la "$OUT_DIR"