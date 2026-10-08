# TalkType

TalkType is a small native macOS menu bar app for voice typing. It recognizes speech on the Mac, formats text locally, and updates the focused text field as words arrive.

[Download TalkType 0.3.1 for Apple Silicon](https://github.com/singhgit2023/talktype/releases/tag/v0.3.1)

## Build and open

Requires macOS 14 or later and Xcode Command Line Tools. Run:

```sh
./scripts/build-app.sh
open dist/TalkType.app
```

The first build creates a persistent **TalkType Local Code Signing** certificate in `.signing/TalkType.keychain-db`. The build script uses it again for future updates and verifies the signed app. Keep the `.signing` directory private and backed up. It contains a keychain and its password, is ignored by Git, and is never copied into the app bundle. Changing or losing that certificate changes the app's signing identity and may make macOS ask for permissions again. The public preview is self-signed and unnotarized; Developer ID signing and notarization would give users a smoother installation.

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

Sparkle 2.10.0 is embedded in the app. Its EdDSA public key is in `Resources/Info.plist`; the private update-signing key is stored in the macOS Keychain under the `TalkType-MacLabb` account, with a local backup in the ignored `.signing/Sparkle-ed25519.key`. Back up `.signing` securely before releasing an update. The app reads [appcast.xml](appcast.xml) on `main` for update information. Users can check manually or control automatic checks in Settings.

Run `./scripts/release.sh` to build the signed app, create the ZIP, SHA-256 checksum, and signed Sparkle appcast entry. Publish the exact ZIP and checksum in the matching GitHub release first, then push `appcast.xml` to `main`. Do not edit the ZIP after generating the appcast signature.

This preview follows the local signing approach used by TabGlide. It is not Apple notarized, so macOS may require manual approval in Privacy & Security after downloading. Keep the same bundle identifier, local certificate, and Sparkle key for later releases. Developer ID signing and notarization remain the path to a smoother public installation.
