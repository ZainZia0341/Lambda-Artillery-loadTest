#!/bin/bash
# load-test.sh - Run multiple Playwright tests in parallel

# Configuration
CONCURRENT_USERS=${1:-10}  # Default 10 concurrent users
TEST_DURATION=${2:-60}     # Default 60 seconds
SCRIPT_FILE="single-test.js"
LOG_DIR="load-test-logs"
RESULTS_FILE="results.txt"

# Create log directory
mkdir -p "$LOG_DIR"
rm -f "$RESULTS_FILE"

echo "Starting load test with $CONCURRENT_USERS concurrent users for $TEST_DURATION seconds"
echo "Test started at: $(date)" | tee -a "$RESULTS_FILE"

# Function to run a single test instance
run_test_instance() {
    local instance_id=$1
    local log_file="$LOG_DIR/instance_${instance_id}.log"
    
    while true; do
        # Check if we should continue
        if [ -f "stop_test.flag" ]; then
            break
        fi
        
        # Run the test
        node "$SCRIPT_FILE" "$instance_id" >> "$log_file" 2>&1
        
        # Log result
        if [ $? -eq 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Instance $instance_id: SUCCESS" >> "$RESULTS_FILE"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Instance $instance_id: FAILED" >> "$RESULTS_FILE"
        fi
        
        # Small delay between iterations
        sleep 1
    done
}

# Start background processes
pids=()
for i in $(seq 1 $CONCURRENT_USERS); do
    run_test_instance $i &
    pids+=($!)
    echo "Started instance $i (PID: ${pids[-1]})"
done

# Run for specified duration
echo "Running for $TEST_DURATION seconds..."
sleep $TEST_DURATION

# Signal stop
touch stop_test.flag

# Wait for all processes to finish
echo "Stopping test instances..."
for pid in ${pids[@]}; do
    wait $pid
done

# Clean up
rm -f stop_test.flag

# Calculate results
echo "Test completed at: $(date)" | tee -a "$RESULTS_FILE"
SUCCESS_COUNT=$(grep -c "SUCCESS" "$RESULTS_FILE")
FAILED_COUNT=$(grep -c "FAILED" "$RESULTS_FILE")
TOTAL_COUNT=$((SUCCESS_COUNT + FAILED_COUNT))

echo "=== Load Test Results ===" | tee -a "$RESULTS_FILE"
echo "Total Requests: $TOTAL_COUNT" | tee -a "$RESULTS_FILE"
echo "Successful: $SUCCESS_COUNT" | tee -a "$RESULTS_FILE"
echo "Failed: $FAILED_COUNT" | tee -a "$RESULTS_FILE"
echo "Success Rate: $(echo "scale=2; $SUCCESS_COUNT * 100 / $TOTAL_COUNT" | bc)%" | tee -a "$RESULTS_FILE"
echo "Requests per second: $(echo "scale=2; $TOTAL_COUNT / $TEST_DURATION" | bc)" | tee -a "$RESULTS_FILE"

echo "Logs saved in: $LOG_DIR"
echo "Results saved in: $RESULTS_FILE"