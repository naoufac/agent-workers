#!/bin/bash
# Quick assign - creates and runs a Claude task immediately

REPO_BASE="${1:-/root/repos/current}"
TASK="$2"

if [[ -z "$TASK" ]]; then
    echo "Usage: $0 <repo_path> <task_description>"
    echo ""
    echo "Example:"
    echo "  $0 /root/repos/myapp 'Fix the auth bug in login.py'"
    exit 1
fi

cd "$REPO_BASE" || {
    echo "ERROR: Cannot cd to $REPO_BASE"
    exit 1
}

echo "Running task in: $(pwd)"
echo "Task: $TASK"
echo ""

claude -p "$TASK" \
    --max-turns 10 \
    --allowedTools "Read,Edit,Write,Bash" \
    --verbose
