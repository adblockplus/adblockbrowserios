# adblockplus-ios
Adblock Browser for iOS
=======================

A web browser for iOS that includes content blocking, provided by AdBlock Plus

Building
————

### Requirements

Note: Adblock Browser requires [ABBCore](https://gitlab.com/eyeo/adblockplus/adblockbrowserios-core) to be cloned into the parent directory from Adblock Browser (this repository).
The directory structure should be configured as such:

```
- adblockbrowser
    |- adblockbrowserios (this repository)
    |- adblockbrowserios-core
```

- [Xcode 9 or later](https://developer.apple.com/xcode/)
- [Carthage](https://github.com/Carthage/Carthage)
- [Sourcery](https://github.com/krzysztofzablocki/Sourcery)
- [SwiftLint](https://github.com/realm/SwiftLint/) (optional)

### Building in Xcode

1. Copy the file `ABB-Secret-API-Env-Vars.sh` (available internally) into the same directory as `AdblockBrowser.xcworkspace`.
2. Run `carthage update` to install additional Swift dependencies. If there are build errors relating to Swift versioning, run `carthage update --no-use-binaries` instead.
3. Open _AdblockBrowser.xcworkspace_ in Xcode.
4. Build and run the project locally in Xcode.