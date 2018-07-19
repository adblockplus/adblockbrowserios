# adblockplus-ios
Adblock Browser for iOS
=======================

A web browser for iOS that includes content blocking, provided by AdBlock Plus

Building
————

### Requirements

- [Xcode 9 or later](https://developer.apple.com/xcode/)
- [Node Package Manager](https://www.npmjs.com)
- [Carthage](https://github.com/Carthage/Carthage)
- [Sourcery](https://github.com/krzysztofzablocki/Sourcery)
- [SwiftLint](https://github.com/realm/SwiftLint/) (optional)

### Building in Xcode

1. Copy the file `ABB-Secret-API-Env-Vars.sh` (available internally) into the same directory as `AdblockBrowser.xcworkspace`.
2. Run `npm install` in '/Core' directory (`jq` is required, can be installed globally using `npm install -g jq`).
3. Run `carthage update` to install additional Swift dependencies.
4. Open _AdblockBrowser.xcworkspace_ in Xcode.
5. Build _KittCore_ target.
6. Build and run the _AdblockBrowser_ target locally in Xcode.
