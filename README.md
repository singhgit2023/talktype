# TalkType

TalkType is a small native macOS menu bar app for voice typing. It recognizes speech on the Mac, formats text locally, and updates the focused text field as words arrive.

## Build and open

Requires macOS 14 or later and Xcode Command Line Tools. Run:

```sh
./scripts/build-app.sh
open dist/TalkType.app
```

The first build creates a persistent **TalkType Local Code Signing** certificate in `.signing/TalkType.keychain-db`. The build script uses it again for future updates and verifies the signed app. Keep the `.signing` directory private and backed up. It contains a keychain and its password, is ignored by Git, and is never copied into the app bundle. Changing or losing that certificate changes the app's signing identity and may make macOS ask for permissions again. This self-signed identity is intended for local use; public distribution needs Apple Developer ID signing and notarization.

Keep the same `com.talktype.mac` bundle identifier and app location across updates. macOS controls privacy permissions, so signing with the same certificate helps maintain identity but cannot guarantee that the system never asks again.

## First run

The welcome guide appears by itself on first launch. It explains the menu bar companion, lets you record a custom hold shortcut, offers seven appearance themes, and guides you through Microphone, Speech Recognition, and Accessibility permissions. Settings opens after you finish the guide. You can reopen it from Settings later.

The small white mascot with eyes and sound-wave marks appears in the macOS menu bar. Click it for the compact popover, Settings, the floating companion, and Quit. TalkType has no Dock icon.
The same mascot is the app's Finder icon. Run `zsh scripts/make-icon.sh` to regenerate it from the included drawing source.

## Use

Put the cursor in a text field and hold your configured shortcut. The default is **⌃ ⌘**. Dictation appears in the focused field as recognition updates arrive. Release the keys to finish. You can also start and stop with the menu bar button. A custom shortcut can be a modifier pair or modifiers with a key.

The compact floating companion puts the mascot and latest spoken words on one line, with the responsive waveform at the right edge. New words appear from left to right; the line scrolls only after filling the available width. Drag anywhere on the bar to move it; it remembers that position. The bar fades away after recording finishes. Dictation keeps listening through natural pauses while the shortcut is held, recovers from temporary recognition interruptions, and keeps earlier words when recognition starts a new phrase. Settings offers Cream, White, Blush, Mint, Lilac, Sky, and Midnight themes, transcript size, companion animations, and a toggle for the gentle start and finish sounds.

TalkType understands “new line,” “new paragraph,” “delete last word,” “bullet point,” and spoken punctuation such as “comma” and “period.” Recognition requires that macOS supports on-device recognition for the selected language.

For compatibility across apps, TalkType uses Paste to update the focused field. It temporarily writes dictated updates to the clipboard and restores previous clipboard contents on completion if no other app changed them.

## Public release

Sparkle 2.9.6 is embedded in the app. Its EdDSA public key is in `Resources/Info.plist`; the private update-signing key is stored in the macOS Keychain under the `TalkType-MacLabb` account. Back up that private key securely before releasing an update. To enable update checks in a release build, provide a publicly reachable HTTPS appcast URL:

```sh
TALKTYPE_UPDATE_FEED_URL=https://example.com/appcast.xml ./scripts/build-app.sh
```

When no feed URL is configured, TalkType leaves Sparkle inactive and explains this in Settings. Once the first signed release and appcast are published, the app will check automatically and offer a manual **Check for Updates…** action. Generate the appcast from signed update archives with Sparkle's `generate_appcast --account TalkType-MacLabb`, and publish that XML at the configured URL.

Before publishing a downloadable GitHub release, choose a project license, complete hands-on app checks, and replace the local self-signed identity with Developer ID signing and notarization. Keep the bundle identifier and signing identity consistent between releases so macOS can recognize the app across updates.
