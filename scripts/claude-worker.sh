#!/bin/bash
# Claude CLI worker - handles autonomous coding tasks

set -e

TASK_DIR="/root/agent-workers/tasks"
REPO_BASE="/root/repos"
LOG_DIR="/root/agent-workers/logs"
MAX_TURNS=15

mkdir -p "$TASK_DIR" "$LOG_DIR"

# Find and execute next pending task
find_task() {
    find "$TASK_DIR" -name "*.json" -type f | while read -r task; do
        status=$(jq -r '.status // "$status"' "$task" 2>/dev/null || echo "error")
        if [[ "$status" == "pending" ]]; then
            echo "$task"
            return
        fi
    done
}

execute_claude_task() {
    local task_file="$1"
    local task_id=$(basename "$task_file" .json)
    local log_file="$LOG_DIR/${task_id}.log"

    echo "[$(date)] Starting task: $task_id" >> "$log_file"

    # Update status to assigned
    jq '.status = "assigned"' "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"

    # Extract task details
    local type=$(jq -r '.type // "code"' "$task_file")
    local repo=$(jq -r '.repo // ""' "$task_file")
    local description=$(jq -r '.description // "No description"' "$task_file")
    local allowed_tools=$(jq -r '.context.allowedTools // "Read,Edit,Write,Bash"' "$task_file")
    local workdir=$(jq -r '.context.workdir // ""' "$task_file")

    # Determine working directory
    if [[ -n "$repo" && -d "$REPO_BASE/$repo" ]]; then
        cd "$REPO_BASE/$repo"
    elif [[ -n "$workdir" && -d "$workdir" ]]; then
        cd "$workdir"
    fi

    echo "[$(date)] Working in: $(pwd)" >> "$log_file"
    echo "[$(date)] Task: $description" >> "$log_file"

    # Execute with Claude CLI
    if claude -p "$description" \
        --max-turns "$MAX_TURNS" \
        --allowedTools "$allowed_tools" \
        --output-format json \
        >> "$log_file" 2>&1; then

        # Success
        jq '.status = "completed" | .completed_at = "'$(date -Iseconds)'"' "$task_file" > "${task_file}.tmp"
        mv "${task_file}.tmp" "$task_file"
        echo "[$(date)] Task completed: $task_id" >> "$log_file"
        return 0
    else
        # Failure
        jq '.status = "failed" | .error = "Claude execution failed" | .failed_at = "'$(date -Iseconds)'"' "$task_file" > "${task_file}.tmp"
        mv "${task_file}.tmp" "$task_file"
        echo "[$(date)] Task failed: $task_id" >> "$log_file"
        return 1
    fi
}

# Main loop
echo "Claude Worker started" >> "$LOG_DIR/worker.log"

while true; do
    task=$(find_task)
    if [[ -n "$task" ]]; then
        execute_claude_task "$task"
    else
        sleep 30
    fi
done
