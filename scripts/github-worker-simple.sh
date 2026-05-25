#!/bin/bash
# Simple GitHub Worker - executes tasks via direct git commands

TASK_DIR="/root/agent-workers/tasks"
REPO_BASE="/root/repos"
LOG_DIR="/root/agent-workers/logs"

mkdir -p "$TASK_DIR" "$REPO_BASE" "$LOG_DIR"

echo "GitHub Worker started" >> "$LOG_DIR/github-worker-simple.log"

find_github_task() {
    find "$TASK_DIR" -name "*.json" -type f | while read -r task; do
        type=$(jq -r '.type // ""' "$task" 2>/dev/null)
        status=$(jq -r '.status // "pending"' "$task" 2>/dev/null)
        
        if [[ "$type" =~ ^github- ]] && [[ "$status" == "pending" ]]; then
            echo "$task"
            return
        fi
    done
}

execute_github_task() {
    local task_file="$1"
    local task_id=$(basename "$task_file" .json)
    local log_file="$LOG_DIR/${task_id}.log"
    
    echo "[$(date)] Starting GitHub task: $task_id" >> "$log_file"
    
    # Mark as assigned
    jq '.status = "assigned"' "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
    
    # Extract task details
    local type=$(jq -r '.type' "$task_file")
    local repo=$(jq -r '.repo // ""' "$task_file")
    local pr_number=$(jq -r '.pr_number // 0' "$task_file")
    local title=$(jq -r '.title // "Untitled"' "$task_file")
    
    case "$type" in
        github-pr-create)
            create_pr_simple "$task_file" "$repo" "$title" "$log_file"
            ;;
        github-pr-review)
            review_pr_simple "$task_file" "$repo" "$pr_number" "$log_file"
            ;;
        *)
            echo "[$(date)] Unknown task type: $type" >> "$log_file"
            jq '.status = "failed" | .error = "Unknown task type"' "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
            return 1
            ;;
    esac
}

create_pr_simple() {
    local task_file="$1"
    local repo="$2"
    local title="$3"
    local log_file="$4"
    
    local branch=$(jq -r '.branch // "main"' "$task_file")
    local body=$(jq -r '.context.body // ""' "$task_file")
    local draft=$(jq -r '.context.draft // "false"' "$task_file")
    
    echo "[$(date)] Creating PR: $title" >> "$log_file"
    
    # Clone repo if needed
    mkdir -p "$REPO_BASE/$repo"
    
    # Create PR using gh CLI
    local pr_cmd="gh pr create --title \"$title\" --body \"$body\" --base main"
    
    if [[ "$draft" == "true" ]]; then
        pr_cmd="$pr_cmd --draft"
    fi
    
    # Execute in repo directory
    cd "$REPO_BASE/$repo" 2>/dev/null || echo "Repo directory missing" >> "$log_file"
    
    if $pr_cmd >> "$log_file" 2>&1; then
        local pr_num=$(gh pr list --head "$branch" --json number --jq '.[0].number')
        jq ".status = \"completed\" | .pr_number = $pr_num | .completed_at = \"$(date -Iseconds)\"" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
        echo "[$(date)] PR created: #$pr_num" >> "$log_file"
        return 0
    else
        jq ".status = \"failed\" | .error = \"PR creation failed\"" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
        echo "[$(date)] Failed to create PR" >> "$log_file"
        return 1
    fi
}

review_pr_simple() {
    local task_file="$1"
    local repo="$2"
    local pr_number="$3"
    local log_file="$4"
    
    local review_type=$(jq -r '.context.review_type // "comment"' "$task_file")
    local body=$(jq -r '.context.body // "Automated review"' "$task_file")
    
    echo "[$(date)] Reviewing PR #$pr_number" >> "$log_file"
    
    cd "$REPO_BASE/$repo" 2>/dev/null
    
    # Post review comment
    local review_cmd="gh pr review $pr_number --$review_type --body \"$body\""
    
    if $review_cmd >> "$log_file" 2>&1; then
        jq ".status = \"completed\" | .completed_at = \"$(date -Iseconds)\"" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
        echo "[$(date)] Review posted to PR #$pr_number" >> "$log_file"
        return 0
    else
        jq ".status = \"failed\" | .error = \"Review failed\"" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
        echo "[$(date)] Failed to review PR" >> "$log_file"
        return 1
    fi
}

# Main loop
while true; do
    task=$(find_github_task)
    if [[ -n "$task" ]]; then
        execute_github_task "$task"
    else
        sleep 30
    fi
done