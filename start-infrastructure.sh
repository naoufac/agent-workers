#!/bin/bash
# Start agent workers monitoring and webhook server

AGENT_WORKERS="/root/agent-workers"
WEBHOOK_SERVER="$AGENT_WORKERS/webhook-server.py"
LOG_DIR="$AGENT_WORKERS/logs"

mkdir -p "$LOG_DIR"

echo "Starting Agent Workers Infrastructure..."
echo ""

# Install dependencies
cd "$AGENT_WORKERS"
pip install -r requirements.txt 2>&1 | grep -v "already satisfied" || echo "Dependencies installed"

# Start webhook server
echo "Starting webhook server on port 8080..."
python3 "$WEBHOOK_SERVER" >> "$LOG_DIR/webhook.log" 2>&1 &
WEBHOOK_PID=$!
echo "Webhook server PID: $WEBHOOK_PID"

# Start Claude worker (if exists)
if [ -f "$AGENT_WORKERS/scripts/claude-worker.sh" ]; then
    echo ""
    echo "Starting Claude worker..."
    bash "$AGENT_WORKERS/scripts/claude-worker.sh" >> "$LOG_DIR/claude.log" 2>&1 &
    CLAUDE_PID=$!
    echo "Claude worker PID: $CLAUDE_PID"
fi

echo ""
echo "=== Infrastructure Running ==="
echo "Webhook URL: http://$(hostname -I | awk '{print $1}'):8080/webhook"
echo "Webhook logs: $LOG_DIR/webhook.log"
echo "Task monitoring: $AGENT_WORKERS/scripts/dispatch.sh list"
echo ""
echo "To stop: kill $WEBHOOK_PID ${CLAUDE_PID:-}"
echo ""
echo "To configure GitHub webhook:"
echo "  1. Go to repo settings → Webhooks"
echo "  2. Add webhook: http://$(hostname -I | awk '{print $1}'):8080/webhook"
echo "  3. Select events: Pull requests"
echo "  4. Set secret (update WEBHOOK_SECRET in webhook-server.py)"
echo ""
echo "Press Ctrl+C to stop"

# Cleanup on exit
cleanup() {
    echo ""
    echo "Stopping infrastructure..."
    kill $WEBHOOK_PID ${CLAUDE_PID:-} 2>/dev/null
    exit 0
}
trap cleanup INT

wait