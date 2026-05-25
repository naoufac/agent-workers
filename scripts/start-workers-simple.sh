#!/bin/bash
# Start both workers (simple versions)

AGENT_WORKERS="/root/agent-workers"
LOG_DIR="$AGENT_WORKERS/logs"

echo "Starting Agent Workers (Simple versions)..."

# Kill existing workers
pkill -f claude-worker 2>/dev/null
pkill -f github-worker-simple 2>/dev/null

sleep 2

# Start GitHub worker
echo "Starting GitHub worker..."
bash "$AGENT_WORKERS/scripts/github-worker-simple.sh" >> "$LOG_DIR/github-worker-simple.log" 2>&1 &
GITHUB_PID=$!
echo "GitHub worker PID: $GITHUB_PID"

echo ""
echo "=== Workers Running ==="
echo "GitHub worker: $LOG_DIR/github-worker-simple.log"
echo "Task directory: $AGENT_WORKERS/tasks/"
echo ""
echo "To stop: kill $GITHUB_PID"
echo "To check tasks: $AGENT_WORKERS/scripts/dispatch.sh list"
echo ""
echo "Press Ctrl+C to stop"

# Cleanup on exit
cleanup() {
    echo ""
    echo "Stopping workers..."
    kill $GITHUB_PID 2>/dev/null
    exit 0
}
trap cleanup INT

wait $GITHUB_PID