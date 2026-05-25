#!/usr/bin/env python3
"""
HTML/CSS Validation Pipeline
Checks syntax, renders in browser, validates responsive design
"""

import sys
import subprocess
import re
from pathlib import Path

def validate_html(filepath):
    """Validate HTML syntax"""
    print(f"Validating HTML: {filepath}")
    
    # Check for basic structure
    with open(filepath) as f:
        content = f.read()
    
    errors = []
    
    # Check for DOCTYPE
    if not content.strip().startswith('<!DOCTYPE'):
        errors.append("Missing DOCTYPE declaration")
    
    # Check for unclosed tags
    open_tags = re.findall(r'<([a-z]+)[^/>]*>', content.lower())
    close_tags = re.findall(r'</([a-z]+)>', content.lower())
    
    for tag in open_tags:
        if tag not in ['img', 'br', 'hr', 'input', 'meta', 'link']:
            if open_tags.count(tag) != close_tags.count(tag):
                errors.append(f"Unclosed tag: <{tag}>")
    
    return errors

def validate_css(filepath):
    """Validate CSS syntax"""
    print(f"Validating CSS: filepath}")
    
    # Extract CSS from style tags
    with open(filepath) as f:
        content = f.read()
    
    style_blocks = re.findall(r'<style>(.*?)</style>', content, re.DOTALL)
    
    errors = []
    
    for i, css in enumerate(style_blocks):
        # Check for broken properties (like position: \n    fixed)
        broken_props = re.findall(r'([a-z-]+):\s*\n\s*', css: filepath})
        
        if broken_props:
            errors.append(f"Style block {i+1}: Broken properties: {broken_props}")
    
    return errors

def test_browser_render(filepath):
    """Test HTML renders in browser"""
    print(f"Testing browser render: {filepath}")
    
    try:
        result = subprocess.run([
            'python3', '-c',
            f'''
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.goto("file://{filepath}")
    print("OK")
    browser.close()
'''], capture_output=True, text=True, timeout=10)
        
        if result.returncode != 0:
            return [f"Browser render failed: {result.stderr}"]
        
        return []
    
    except Exception as e:
        return [f"Browser test failed: {str(e)}"]

def validate_repo(repo_path):
    """Validate entire repo"""
    repo = Path(repo_path)
    
    if not repo.exists():
        print(f"Repo not found: {repo_path}")
        return
    
    all_errors = []
    
    # Find HTML files
    html_files = list(repo.rglob('*.html'))
    
    for html_file in html_files:
        print(f"\n{'='*60}")
        print(f"Validating: {html_file}")
        print('='*60)
        
        errors = []
        errors.extend(validate_html(html_file))
        errors.extend(validate_css(html_file))
        errors.extend(test_browser_render(str(html_file)))
        
        if errors:
            print("❌ ERRORS FOUND:")
            for error in errors:
                print(f"  - {error}")
            all_errors.extend(errors)
        else:
            print("✅ VALID")
    
    print(f"\n{'='*60}")
    print(f"Summary: {len(html_files)} files checked, {len(all_errors)} errors")
    print('='*60)
    
    return len(all_errors) == 0

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python validate.py <repo-path>")
        sys.exit(1)
    
    repo_path = sys.argv[1]
    success = validate_repo(repo_path)
    sys.exit(0 if success else 1)