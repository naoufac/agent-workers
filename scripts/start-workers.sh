#!/bin/bash
# Start both workers in background and monitor them

AGENT_WORKERS="/root/agent-workers"
CLAUDE_LOG="$AGENT_WORKERS/logs/worker.log"
GITHUB_LOG="$AGENT_WORKERS/logs/github-worker.log"

mkdir -p "$AGENT_WORKERS/logs"

echo "Starting Agent Workers..."
echo "Claude worker: $AGENT_WORKERS/scripts/claude-worker.sh"
echo "GitHub worker: $AGENT_WORKERS/scripts/github-worker.sh"

# Start Claude worker
bash "$AGENT_WORKERS/scripts/claude-worker.sh" >> "$CLAUDE_LOG" 2>&1 &
CLAUDE_PID=$!

# Start GitHub worker
bash "$AGENT_WORKERS/scripts/github-worker.sh" >> "$GITHUB_LOG" 2>&1 &
GITHUB_PID=$!

echo "Claude worker PID: $CLAUDE_PID"
echo "GitHub worker PID: $GITHUB_PID"
echo ""
echo "Workers are running. Logs:"
echo "  Claude: $CLAUDE_LOG"
echo "  GitHub: $GITHUB_LOG"
echo ""
echo "To stop: kill $CLAUDE_PID $GITHUB_PID"
echo "To check tasks: $AGENT_WORKERS/scripts/dispatch.sh list"
echo ""
echo "Press Ctrl+C to stop all workers"

# Trap Ctrl+C
cleanup() {
    echo ""
    echo "Stopping workers..."
    kill $CLAUDE_PID $GITHUB_PID 2>/dev/null
    exit 0
}
trap cleanup INT

# Wait for workers
wait $CLAUDE_PID $GITHUB_PID
