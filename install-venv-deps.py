#!/usr/bin/env python3
"""Install Flask in venv"""

import subprocess
import sys

venv_python = "/root/agent-workers/venv/bin/python3"

try:
    print("Installing Flask and Gunicorn...")
    result = subprocess.run([
        venv_python, '-m', 'pip', 'install',
        'flask==3.0.0', 'gunicorn==21.2.0',
        '--break-system-packages'
    ], capture_output=True, text=True, timeout=300)
    
    if result.returncode == 0:
        print("✅ Installation successful")
        
        # Test import
        test_result = subprocess.run([
            venv_python, '-c',
            'import flask; import gunicorn; print("OK")'
        ], capture_output=True, text=True)
        
        if test_result.returncode == 0:
            print("✅ Flask and Gunicorn import OK")
        else:
            print(f"❌ Import failed: {test_result.stderr}")
            sys.exit(1)
    else:
        print(f"❌ Installation failed:\n{result.stderr}")
        sys.exit(1)
        
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)