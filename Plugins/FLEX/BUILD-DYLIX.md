# FLEX 1.0.2 for Dylix 1.1.0 Build220

Corresponding source for the bundled rootless arm64 deb and dylib. Existing per-file copyright and third-party notices apply.

Build with Xcode command-line tools and Theos installed: `LC_ALL=C LANG=C make package FINALPACKAGE=1 DEBUG=0 -j1`. Set THEOS to your local Theos installation. The shipped plugin was built with SDK18.2. The main Dylix app uses SDK26.0.

See Dylix docs/BUILD210_FLEX_STATUS.md for state and screenshot behavior and test limitations.

Build220 retains only LAN/private IPv4 and same-device HTTP connections. Internet relay and VPN overlay support were removed at the user's request. The selected local address and actual port continue to be stored by the existing preferences layer; see docs/REMOTE_LOCAL.md in the Dylix source.
