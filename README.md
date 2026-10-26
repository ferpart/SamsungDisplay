# SamsungDisplay

Menu bar app for macOS 26. It controls a Samsung smart monitor over the Tizen WebSocket API. The Mac volume and mute keys control the monitor when it is the audio output.

## Build

1. Run `xcodegen generate`.
2. Open `SamsungDisplay.xcodeproj` and run the `SamsungDisplay` scheme.

## Signing

The build is ad-hoc signed by default. Each build then gets a new signature. macOS asks again for the Keychain password and resets the key permission.

To keep one signature across builds:

1. Copy `Signing.local.xcconfig.example` to `Signing.local.xcconfig`.
2. Remove the `//` marks from both lines.
3. Set `DEVELOPMENT_TEAM` to your Apple Developer team ID.
4. Set `CODE_SIGN_IDENTITY` to your certificate name, for example `Apple Development`.
5. Run `xcodegen generate` and build again.

Git ignores `Signing.local.xcconfig`. Without the file, the build stays ad-hoc.
