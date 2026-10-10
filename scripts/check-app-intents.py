#!/usr/bin/env python3
"""Verify the packaged actions exist in both possible macOS execution targets."""
import json
import sys
from pathlib import Path

# Each widget action and the parameters it must carry.
ACTIONS = {'SetFanIntent': ['notch'], 'CycleFanTimerIntent': []}

app = Path(sys.argv[1])
for bundle in (app, app / 'Contents/PlugIns/FanLeverWidget.appex'):
    metadata = bundle / 'Contents/Resources/Metadata.appintents/extract.actionsdata'
    if not metadata.is_file():
        sys.exit(f'FAIL: {bundle.name} has no App Intent metadata')
    actions = json.loads(metadata.read_text()).get('actions', {})
    for name, parameters in ACTIONS.items():
        action = actions.get(name)
        present = {p['name'] for p in action.get('parameters', [])} if action else set()
        if not action or not set(parameters) <= present:
            sys.exit(f'FAIL: {bundle.name} is missing {name}' + ''.join(f'/{p}' for p in parameters))
        if action.get('openAppWhenRun'):
            sys.exit(f'FAIL: {bundle.name} opens the app for {name}')
        print(f'PASS: {bundle.name} contains background {name}' + ''.join(f'/{p}' for p in parameters))
