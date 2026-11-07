"""Select the actual app-link SDK, independently of SDK resources bundled for projects."""
import json
import pathlib
import plistlib


def sdk_settings(root):
    root = pathlib.Path(root)
    path = root / 'SDKSettings.json'
    return json.loads(path.read_text()) if path.exists() else plistlib.loads((root / 'SDKSettings.plist').read_bytes())


def select_sdk(platform, installed, bundled, explicit=None):
    """Device releases default to SDK 26+. An explicit SDK remains available for compatibility tests."""
    chosen = pathlib.Path(explicit) if explicit else pathlib.Path(installed)
    if not explicit and platform == 'iphoneos':
        if int(sdk_settings(chosen)['Version'].split('.')[0]) < 26:
            chosen = pathlib.Path(bundled)
            if not chosen.is_dir() or int(sdk_settings(chosen)['Version'].split('.')[0]) < 26:
                raise ValueError('Device builds require an iOS 26+ SDK by default. Set DYLIX_SDK_26_0 or --sdk-root; refusing a silent older-SDK release.')
    settings = sdk_settings(chosen)
    if platform not in settings.get('SupportedTargets', {}):
        raise ValueError('SDK platform does not match build target: ' + platform)
    return chosen.resolve(), settings
