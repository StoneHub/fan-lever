#!/usr/bin/env python3
"""Verify the packaged action exists in both possible macOS execution targets."""
import json
import sys
from pathlib import Path

app = Path(sys.argv[1])
for bundle in (app, app / 'Contents/PlugIns/FanLeverWidget.appex'):
    metadata = bundle / 'Contents/Resources/Metadata.appintents/extract.actionsdata'
    if not metadata.is_file():
        sys.exit(f'FAIL: {bundle.name} has no App Intent metadata')
    action = json.loads(metadata.read_text()).get('actions', {}).get('SetFanIntent')
    if not action or not any(p['name'] == 'notch' for p in action.get('parameters', [])):
        sys.exit(f'FAIL: {bundle.name} is missing SetFanIntent/notch')
    if action.get('openAppWhenRun'):
        sys.exit(f'FAIL: {bundle.name} opens the app for widget actions')
    print(f'PASS: {bundle.name} contains background SetFanIntent/notch')
