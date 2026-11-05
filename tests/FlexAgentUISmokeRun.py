#!/usr/bin/env python3
"""UIKit smoke test of production FLEX chat/runtime with fixture HTTP transport.

Usage: python3 tests/FlexAgentUISmokeRun.py --flex /path/to/FLEX --device booted
Requires a booted iOS Simulator. Does not contact models or modify target Apps.
"""
import argparse
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--flex', type=Path, required=True)
parser.add_argument('--device', default='booted')
parser.add_argument('--persistence', action='store_true')
parser.add_argument('--diagnostics', action='store_true')
args = parser.parse_args()
app = Path(tempfile.mkdtemp(prefix='flex-ui-smoke-')) / 'FlexAgentUISmoke.app'
app.mkdir()
bundle = 'app.dylix.tests.flex-agent-ui'
plist = dict(CFBundleIdentifier=bundle, CFBundleName='FLEX Agent UI Smoke',
             CFBundleExecutable='FlexAgentUISmoke', CFBundlePackageType='APPL',
             CFBundleVersion='1', CFBundleShortVersionString='1.0',
             MinimumOSVersion='15.0', UIDeviceFamily=[1, 2],
             UILaunchScreen={})
(app / 'Info.plist').write_bytes(plistlib.dumps(plist))
entitlements=app.parent/'sim-entitlements.plist'
entitlements.write_bytes(plistlib.dumps({'application-identifier':'DYLIxTEST.'+bundle,'keychain-access-groups':['DYLIxTEST.'+bundle]}))
sources = ['FLEXDylixTouchDriver.m', 'FLEXDylixChatViewController.m', 'FLEXDylixRuntime.m',
           'FLEXDylixAddress.m', 'FLEXDylixConnection.m', 'FLEXDylixPreferences.m', 'FLEXDylixMarkdown.m', 'FLEXDylixStatusWindow.m', 'FLEXGlobalsEntry.m']
subprocess.run(['xcrun', '--sdk', 'iphonesimulator', 'clang', '-target',
                'arm64-apple-ios15.0-simulator', '-fobjc-arc', '-fblocks', '-w',
                '-I', str(args.flex), str(Path(__file__).with_name('FlexAgentUISmoke.m')),
                *[str(args.flex / name) for name in sources],
                '-framework', 'Foundation', '-framework', 'UIKit',
                '-framework', 'Security', '-framework', 'CoreGraphics',
                '-Xlinker', '-sectcreate', '-Xlinker', '__TEXT', '-Xlinker', '__entitlements', '-Xlinker', str(entitlements),
                '-o', str(app / 'FlexAgentUISmoke')], check=True)
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
def sim(*argv, **kwargs):
    return subprocess.run(['xcrun', 'simctl', *argv], check=True, **kwargs)
subprocess.run(['xcrun', 'simctl', 'terminate', args.device, bundle], capture_output=True)
sim('install', args.device, str(app))
container = Path(sim('get_app_container', args.device, bundle, 'data', capture_output=True,
                     text=True).stdout.strip())
report = container / 'Documents/results.json'
report.unlink(missing_ok=True)
sim('launch', args.device, bundle)
deadline = time.monotonic() + 55
while not report.exists() and time.monotonic() < deadline:
    time.sleep(.2)
if not report.exists():
    raise SystemExit('No results.json produced: inspect Simulator crash logs')
result = json.loads(report.read_text())
for item in result['checks']:
    print(('PASS ' if item['passed'] else 'FAIL ') + item['name'])
print(f"RESULT {len(result['checks'])} checks {result['failures']} failures")
destination = Path(os.environ.get('FLEX_UI_RESULT', '/private/tmp/flex-agent-ui-results.json'))
destination.write_text(json.dumps(result, ensure_ascii=False, indent=2))
print('Report:', destination)
if args.persistence or args.diagnostics:
    phases=(['write','read','disconnect','cleared'] if args.persistence else [])+(['diagnostics'] if args.diagnostics else [])
    for phase in phases:
        subprocess.run(['xcrun','simctl','terminate',args.device,bundle],capture_output=True)
        if phase == 'read':
            # Replace the installed App while preserving its data container.
            sim('install',args.device,str(app))
            container=Path(sim('get_app_container',args.device,bundle,'data',capture_output=True,text=True).stdout.strip())
            report=container/'Documents/results.json'
        report.unlink(missing_ok=True)
        sim('launch',args.device,bundle,'--connection-diagnostics' if phase=='diagnostics' else '--preferences-'+phase)
        deadline=time.monotonic()+20
        while not report.exists() and time.monotonic()<deadline:
            time.sleep(.2)
        if not report.exists():raise SystemExit('No persistence report for '+phase)
        step=json.loads(report.read_text())
        (destination.parent / ('flex-preferences-'+phase+'.json')).write_text(json.dumps(step,ensure_ascii=False,indent=2))
        for item in step['checks']: print(('PASS ' if item['passed'] else 'FAIL ')+item['name'])
        result['checks'].extend(step['checks']);result['failures']+=step['failures']
    destination.write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(f"COMBINED RESULT {len(result['checks'])} checks {result['failures']} failures")
raise SystemExit(bool(result['failures']))
