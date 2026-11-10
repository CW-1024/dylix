# FLEX 1.0.4 / Dylix Build255

按服务器支持档位选择深度思考，发送 reasoningEffort；未选择时沿用同模型会话的实际设置。需要 Dylix Build255 或更新版本。

# FLEX 1.0.3 for Dylix 1.1.1 Build236

Corresponding source for the bundled rootless arm64 deb and dylib. Existing per-file copyright and third-party notices apply.

Build with Xcode command-line tools and Theos installed: `LC_ALL=C LANG=C make package FINALPACKAGE=1 DEBUG=0 -j1`. Set THEOS to your local Theos installation. The shipped plugin was built with SDK18.2. The main Dylix app uses SDK26.0.

See Dylix docs/BUILD210_FLEX_STATUS.md for state and screenshot behavior and test limitations.

Build220 retains only LAN/private IPv4 and same-device HTTP connections. Internet relay and VPN overlay support were removed at the user's request. The selected local address and actual port continue to be stored by the existing preferences layer; see docs/REMOTE_LOCAL.md in the Dylix source.

The main Dylix source archive includes this complete Plugins/FLEX directory. The release also provides FLEX-1.0.2-source.zip separately, including the plugin source, Makefile, root project license and third-party notices. The 1.1.1 Build225 connection fixes are in the main App and do not change the FLEX 1.0.2 binary.

## FLEX 1.0.3 / Build236

Three-finger and four-finger long presses (0.5 seconds) both toggle FLEX. The activation recognizers coexist with host/third-party gestures, while the two FLEX shortcuts stay mutually exclusive to avoid double toggles. The bundled project template carries the same implementation. Test with `python3 tests/FlexActivationGesturesRun.py`; the test-only injector supports four touches without changing the production AI gesture limit. Simulator checks do not guarantee behavior with every injected third-party plugin or system gesture on a real device.
