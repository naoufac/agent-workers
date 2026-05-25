#!/bin/bash
# Social Media Production Automation

SCHEDULER_DIR="/root/agent-workers/tasks"
LOG_DIR="/root/agent-workers/logs"
CONTENT_DIR="/root/social-content"

mkdir -p "$SCHEDULER_DIR" "$LOG_DIR" "$CONTENT_DIR"

create_content_task() {
    local platform=$1
    local content_type=$2
    local timestamp=$(date -Iseconds)
    local task_id="social-${timestamp}"
    local title="Social Media automation: $platform"
    
    cat > "$SCHEDULER_DIR/${task_id}.json" <<EOF
{
  "id": "$task_id",
  "type": "social-content-create",
  "priority": "medium",
  "status": "pending",
  "created_at": "$timestamp",
  "title": "$title",
  "description": "Create $content_type content for $platform platform",
  "context": {
    "platform": "$platform",
    "content_type": "$content_type",
    "output_dir": "$CONTENT_DIR/$platform"
  }
}
EOF
    
    echo "Created task: $task_id - $title"
}

echo "Creating social media content tasks..."
create_content_task "telegram" "post"
create_content_task "discord" "post"
create_content_task "x" "post"

echo ""
echo "=== Tasks Created ==="
echo "3 social content tasks added to queue"
echo ""
echo "Next: GitHub worker will process tasks and publish content"