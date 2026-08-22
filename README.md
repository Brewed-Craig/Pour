# Pour

Push-to-talk dictation for macOS. Hold **`** (backtick), talk, let go — the text lands in
whatever field you were already in. Dictation audio and text are processed on this Mac and
aren't uploaded by Pour. macOS may contact Apple to download required speech-model assets.

A free, open-source Brewed AI passion project. Pour is independent and is not affiliated with
Wispr Flow or Wispr AI.

---

## Requirements

- macOS 26 (Tahoe) or newer — Pour is built on the `SpeechAnalyzer` API introduced there
- Xcode 26 with the command line tools selected (`sudo xcode-select -s /Applications/Xcode.app`)
- Apple Silicon

## Build and run

```sh
./build.sh doctor     # check the toolchain and find your signing identity
./build.sh run        # build, bundle, sign, launch in the foreground
```

`run` launches Pour in the foreground so you can see its logs. Quit with ⌃C, or from the
menu bar item.

### Signing (read this before the first run)

macOS ties the Accessibility grant to the app's **signed identity**. Ad-hoc signing produces
a new identity on every build, so Pour's hotkey and text injection will silently stop working
after each rebuild and you'll waste an afternoon debugging the wrong layer.

`build.sh` looks for a `Developer ID Application` certificate automatically. If you have more
than one, pin it:

```sh
SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./build.sh run
```

To re-test the permission flow from scratch:

```sh
./build.sh reset
```

## First launch

1. macOS asks for **Microphone** access → allow.
2. Pour asks for **Accessibility** access and opens System Settings → add and enable Pour.
3. Choose **Retry Setup** from the menu bar item.
4. On the very first run the OS downloads the speech model for your locale. The menu shows
   progress. This happens once.

The menu bar cup tells you the state: outline = ready, amber = listening, blue = transcribing,
green = delivered, red triangle = something's blocked (the menu says what).

## How the hotkey behaves

- **Hold `** — dictates while held.
- **Tap ` quickly** (under 220ms) — types a literal backtick, as normal. You don't lose the key.
- **⌘` / ⌃` / ⌥`** — passes straight through; those are real shortcuts.
- **Esc while holding** — discards the dictation.

Change the key in `Sources/HotkeyKit/PushToTalkHotkey.swift` → `Config.keyCode`.

## Privacy

- Pour starts the microphone engine after permission is granted and keeps a rolling 300 ms
  pre-roll in memory so the first syllable is not clipped. The buffer is never written to disk;
  only the pre-roll and audio captured while the key is held reach Apple's on-device analyzer.
- Pour does not upload dictation audio or transcript text. macOS may download an OS-managed
  speech model from Apple when a locale is used for the first time.
- Transcripts and target-app names are stored locally in
  `~/Library/Application Support/Pour/history.json` and automatically removed after five days.
- Dictionary entries and settings stay in the current macOS user account.
- When direct Accessibility insertion is unavailable, Pour briefly places the transcript on the
  clipboard, pastes it, and restores the previous clipboard contents if nothing else changed them.

---

## Layout

```
Sources/
  Pour/              menu bar app — status item, app delegate. Thin on purpose.
  FlowCore/          state machine, permissions. Owns the hot path.
  HotkeyKit/         CGEventTap push-to-talk with tap-to-type passthrough
  AudioCapture/      always-warm AVAudioEngine with a 300ms pre-roll buffer
  TranscriptionKit/  SpeechEngine protocol + AppleSpeechEngine
  InjectKit/         Accessibility insert → clipboard paste fallback
  DictionaryKit/     personal vocabulary, corrections, and conservative risk warnings
  DesignKit/         reusable visual components and bundled fonts
```

Two design decisions worth knowing before you edit anything:

**The mic never stops.** Starting `AVAudioEngine` on key-down costs 150–250ms and clips your
first syllable. It runs from launch instead, converting continuously, and key-down just opens
a gate — flushing 300ms of pre-roll so the start of the word isn't lost.

**Everything goes through one serial command loop.** `DictationController` processes press /
release / cancel one at a time. Press and release can arrive milliseconds apart while
`beginUtterance` is still awaiting, and without serialization that race eats the first
dictation of every session.

## Included now

- Menu-bar controls and configurable push-to-talk hotkey
- Live non-activating HUD and level meter
- Five-day searchable local transcription history
- Personal vocabulary and correction dictionary
- Locale/model picker and settings window

## Possible next steps

- **RefineKit** — the cleanup pass (filler removal, backtrack resolution, list formatting) via
  a local MLX model, plus personal dictionary and snippets. Hooks in at the marked spot in
  `DictationController.finishCapture()`.
- Per-app profiles, engine picker, launch-at-login, and a notarized DMG.

## Notes

- Swift 5 language mode is deliberate (`Package.swift`). Strict concurrency checking across
  CoreGraphics event taps and `AVAudioEngine` callbacks still needs focused work.
- Not sandboxed, and can't be — `CGEventTap` and the Accessibility API don't work inside the
  App Sandbox. Distribution is a notarized DMG.
- `TextInjector.pasteOnlyBundleIDs` lists apps whose Accessibility text-setting is unreliable
  (Electron, Chromium). Add to it as you find more; the menu's last-transcript line tells you
  which strategy each dictation used.

## Licenses

Pour's source code is available under the [MIT License](LICENSE).
Bundled fonts have their own SIL Open Font License terms; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
