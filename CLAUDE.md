# Agent Workers Repository

This repo manages autonomous coding tasks via Claude CLI and GitHub workers.

## Architecture
- **Task Files**: JSON files in `tasks/` directory define specific work items
- **Claude CLI**: Uses print mode (-p) for non-interactive execution
- **GitHub Workers**: gh CLI or REST API for PR operations
- **Task Assignment**: Tasks are assigned via cron jobs or manual dispatch

## Task File Structure
```json
{
  "id": "unique-task-id",
  "type": "claude-code | github-pr | github-review",
  "priority": "high | medium | low",
  "status": "pending | assigned | completed | failed",
  "title": "Human-readable title",
  "description": "Detailed task description",
  "repo": "owner/repo",
  "branch": "target-branch",
  "context": {
    "files": ["relative/paths"],
    "commands": ["run", "these"],
    "review_focus": "security, performance"
  }
}
```

## Claude CLI Patterns
- Print mode: `claude -p "task" --max-turns 10 --allowedTools "Read,Edit,Bash"`
- Worktrees: `claude -w feature-name` for isolated work
- JSON output: `--output-format json` for structured results

## GitHub Worker Patterns
- PR creation: `gh pr create --title` + `--body`
- CI monitoring: `gh pr checks --watch`
- Review: `gh pr review --approve` or `--request-changes`

## Quality Gates
- All tasks require `max-turns` to prevent runaway
- PR tasks wait for CI green before merge
- Review tasks follow structured output format

## Current Workers
- **claude-primary**: Main coding agent
- **claude-secondary**: Parallel workstream agent
- **github-bot**: PR lifecycle manager
