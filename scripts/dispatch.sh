#!/bin/bash
# Task dispatcher - creates and assigns tasks to workers

TASK_DIR="/root/agent-workers/tasks"
LOG_DIR="/root/agent-workers/logs"

mkdir -p "$TASK_DIR" "$LOG_DIR"

generate_task_id() {
    echo "task-$(date +%Y%m%d-%H%M%S)-$(shuf -i 1000-9999 -n 1)"
}

# Task creation helpers
create_code_task() {
    local title="$1"
    local description="$2"
    local repo="$3"
    local task_id=$(generate_task_id)

    cat > "$TASK_DIR/${task_id}.json" <<EOF
{
  "id": "$task_id",
  "type": "claude-code",
  "priority": "medium",
  "status": "pending",
  "created_at": "$(date -Iseconds)",
  "title": "$title",
  "description": "$description",
  "repo": "$repo",
  "context": {
    "allowedTools": "Read,Edit,Write,Bash"
  }
}
EOF
    echo "$task_id"
}

create_pr_task() {
    local title="$1"
    local body="$2"
    local repo="$3"
    local branch="${4:-main}"
    local task_id=$(generate_task_id)

    cat > "$TASK_DIR/${task_id}.json" <<EOF
{
  "id": "$task_id",
  "type": "github-pr-create",
  "priority": "high",
  "status": "pending",
  "created_at": "$(date -Iseconds)",
  "title": "$title",
  "description": "Create PR for: $title",
  "repo": "$repo",
  "branch": "$branch",
  "context": {
    "body": "$body",
    "draft": false
  }
}
EOF
    echo "$task_id"
}

create_review_task() {
    local pr_num="$1"
    local repo="$2"
    local review_type="${3:-comment}"
    local body="$4"
    local task_id=$(generate_task_id)

    cat > "$TASK_DIR/${task_id}.json" <<EOF
{
  "id": "$task_id",
  "type": "github-pr-review",
  "priority": "medium",
  "status": "pending",
  "created_at": "$(date -Iseconds)",
  "title": "Review PR #$pr_num",
  "description": "Review PR #$pr_num on $repo",
  "repo": "$repo",
  "pr_number": $pr_num,
  "context": {
    "review_type": "$review_type",
    "body": "$body"
  }
}
EOF
    echo "$task_id"
}

list_tasks() {
    echo "=== Pending Tasks ==="
    find "$TASK_DIR" -name "*.json" -type f -exec jq -r '[.id, .status, .title] | @tsv' {} \; 2>/dev/null | \
    awk -F'\t' '$2=="pending" {print "  ["$1"] "$3}'

    echo -e "\n=== Assigned Tasks ==="
    find "$TASK_DIR" -name "*.json" -type f -exec jq -r '[.id, .status, .title] | @tsv' {} \; 2>/dev/null | \
    awk -F'\t' '$2=="assigned" {print "  ["$1"] "$3}'

    echo -e "\n=== Completed Tasks ==="
    find "$TASK_DIR" -name "*.json" -type f -exec jq -r '[.id, .status, .title] | @tsv' {} \; 2>/dev/null | \
    awk -F'\t' '$2=="completed" {print "  ["$1"] "$3}'
}

case "${1:-}" in
    code)
        shift
        create_code_task "$@"
        ;;
    pr)
        shift
        create_pr_task "$@"
        ;;
    review)
        shift
        create_review_task "$@"
        ;;
    list)
        list_tasks
        ;;
    *)
        echo "Task Dispatcher"
        echo ""
        echo "Usage: $0 {code|pr|review|list} [args...]"
        echo ""
        echo "Commands:"
        echo "  code <title> <description> <repo>      - Create Claude code task"
        echo "  pr <title> <body> <repo> [branch]      - Create PR task"
        echo "  review <pr_num> <repo> [type] <body>   - Create review task"
        echo "  list                                     - List all tasks"
        ;;
esac
