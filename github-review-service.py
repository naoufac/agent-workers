#!/usr/bin/env python3
"""
GitHub Review Service
Posts code review comments to GitHub PRs
"""

import os
import json
import subprocess
from pathlib import Path

class GitHubReviewService:
    def __init__(self, repo, token=None):
        self.repo = repo
        self.token = token or os.getenv('GITHUB_TOKEN')
        
    def post_review_comment(self, pr_number, comment):
        """Post review comment to PR"""
        cmd = [
            'gh', 'api',
            f'repos/{self.repo}/issues/{pr_number}/comments',
            '-f', f'body={comment}'
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"Failed to post comment: {result.stderr}")
            return False
        
        print(f"✓ Posted comment to PR #{pr_number}")
        return True
    
    def create_status_check(self, commit_sha, status, description, context='hermes-review'):
        """Create GitHub status check"""
        cmd = [
            'gh', 'api',
            f'repos/{self.repo}/statuses/{commit_sha}',
            '-f', f'state={status}',
            '-f', f'description={description}',
            '-f', f'context={context}'
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"Failed to create status: {result.stderr}")
            return False
        
        print(f"✓ Created status check: {status}")
        return True
    
    def review_pr(self, pr_number, validation_results):
        """Review PR based on validation results"""
        
        # Build review comment
        comment_lines = ["## Hermes Code Review\n"]
        
        has_errors = False
        
        for result in validation_results:
            if result['errors']:
                has_errors = True
                comment_lines.append(f"\n### ❌ {result['file']}\n")
                for error in result['errors']:
                    comment_lines.append(f"- {error}")
            else:
                comment_lines.append(f"\n### ✅ {result['file']}\n")
                comment_lines.append("- No issues found")
        
        comment_lines.append("\n---\n*Automated review by Hermes Agent Workers*")
        comment = '\n'.join(comment_lines)
        
        # Post comment
        self.post_review_comment(pr_number, comment)
        
        # Create status check
        status = 'failure' if has_errors else 'success'
        description = 'Code review failed' if has_errors else 'Code review passed'
        self.create_status_check(pr_number, status, description)
        
        return not has_errors

def load_validation_results(results_file):
    """Load validation results from JSON"""
    with open(results_file) as f:
        return json.load(f)

if __name__ == '__main__':
    import sys
    
    if len(sys.argv) < 4:
        print("Usage: python github-review-service.py <repo> <pr_number> <results_file>")
        sys.exit(1)
    
    repo = sys.argv[1]
    pr_number = sys.argv[2]
    results_file = sys.argv[3]
    
    service = GitHubReviewService(repo)
    results = load_validation_results(results_file)
    
    success = service.review_pr(pr_number, results)
    sys.exit(0 if success else 1)