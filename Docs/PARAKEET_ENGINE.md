# Parakeet engine

A second `SpeechEngine` (Parakeet, via [FluidAudio](https://github.com/FluidInference/FluidAudio))
alongside Apple's SpeechAnalyzer, switchable in Settings → Model → Engine.

**Status: working, lightly tested.** A model download completed successfully, the app
transcribed and delivered a real dictated sentence through it, and the re-entrancy bug that
paused this work mid-session has been fixed and retested. Apple's engine is untouched and
remains the default for anyone who doesn't open the picker.

## What's done

- `Sources/ParakeetKit/ParakeetSpeechEngine.swift` — a `SpeechEngine` conformance wrapping
  FluidAudio's `StreamingEouAsrManager` (an actor). Bridges the actor's async API into
  `SpeechEngine`'s synchronous, audio-thread-safe `feed(_:)` the same way `AppleSpeechEngine`
  bridges `SpeechAnalyzer` — buffers queue into an `AsyncStream`, a background `Task` drains it.
- `DictationController.engineFactory` — injectable property
  (`(Locale, ((Double) -> Void)?) async throws -> any SpeechEngine`), defaulting to Apple's
  engine. This is the whole seam; `FlowCore` still doesn't know Parakeet exists.
- `DictationController.start()` is generation-guarded (see "Re-entrancy fix" below) — safe to
  call again (an engine or locale switch) before a prior call has resolved.
- `AppSettings.engineKind: EngineKind` (`.apple` / `.parakeet`), default `.apple`, decoded with
  a fallback so existing users' settings files aren't affected.
- `AppModel.setEngineKind(_:onDownloadProgress:)` — swaps the factory and restarts the
  controller, same pattern as `setLocale`.
- Settings → Model → Engine: a segmented Apple/Parakeet picker. Language picker disables
  itself when Parakeet is selected (English-only for now, via the 120M EOU model).
- `Package.swift` — FluidAudio pinned to `exact: "0.15.6"` (confirmed API-compatible with the
  code above by diffing `main` against the tag before writing anything).

## Confirmed live

- Everything builds clean, including a full `./build.sh app` release build.
- Apple engine, launched fresh: `Ready · press ` to dictate` — unaffected throughout.
- Switching Settings → Engine → Parakeet triggers a real download with live progress reporting
  (`FluidAudio`'s `ProgressHandler` → the same UI Apple's asset download already uses).
- **A Parakeet model finished loading and transcribed real speech.** A dictated sentence was
  captured, transcribed, corrected, and delivered into another app (Ghostty) via the normal
  paste path — the full pipeline, not just the load.
- A genuinely corrupted download (`weight.bin` empty file) was caught by FluidAudio's own
  validation and surfaced correctly through the existing `.blocked(reason)` → "Retry Setup" flow.
- **Re-entrancy fix retested live**: rapidly clicking Parakeet then Apple in Settings (to force
  two `start()` calls to overlap) now settles cleanly on whichever was clicked last — no stuck
  "Downloading" state, no stale engine left running.

## Re-entrancy fix (was the blocker; now fixed)

`start()` didn't cancel a still-in-flight prior call. Switching engines mid-download let two
loads race: both could try to commit `self.engine`/`self.capture` with no ordering guarantee,
and both `onDownloadProgress` closures stayed alive and kept firing after being superseded —
observed as the Settings UI showing "Downloading speech model… 26%" for an *abandoned* attempt
several seconds after switching back to Apple.

Fixed with a generation counter: `start()` bumps `startGeneration` and captures it; every commit
point (permission-denied states, the engine/capture assignment, the progress forwarder, the
error path) checks its captured generation against the current one and bails if superseded —
discarding a stale-but-successful engine load via `cancelUtterance()` rather than letting it
clobber whatever the newer call already set up. `Task` cancellation alone wasn't an option since
the FluidAudio download call isn't itself cancellable.

This wasn't Parakeet-specific — it was latent in `start()`/`updateLocale()` any time one was
called before a prior call resolved, just far more likely to hit once an engine's setup can take
much longer than Apple's near-instant path.

## What's still not confirmed

- **Transcription quality/latency over more than one real sentence.** Only one live dictation
  has actually been evaluated end-to-end.
- Whether `StreamingEouAsrManager`'s `setPartialTranscriptCallback` gives usably fast/accurate
  live preview text during longer utterances, or whether it's better to suppress the preview and
  only show `finish()`'s result.
- Behavior on a slow/flaky connection beyond the one corrupted-file case already seen — the
  progress-bar non-monotonicity noted below hasn't been re-checked since the re-entrancy fix.

## Also worth knowing

- **Progress isn't monotonic.** FluidAudio reports progress per-file across several required
  model files (encoder/decoder/joint/tokenizer), so the UI can jump around (e.g. 40% → 12%) as
  each new file's download starts. Not a bug in the glue code — consider smoothing it in the UI
  (track a running max) if it reads as broken to a first-time user.
- **No contextual biasing wired for Parakeet.** `updateContext(vocabulary:)` is a no-op (uses
  `SpeechEngine`'s default) — FluidAudio's streaming EOU manager doesn't expose anything
  equivalent to Apple's `AnalysisContext` in what was reviewed. Dictionary correction (the
  guaranteed post-transcription pass) still applies regardless of engine, unaffected.
- **English-only in this integration.** Parakeet TDT v3 supports 25 languages per FluidAudio's
  docs, but this integration only wired the English-only 120M EOU streaming model
  (`parakeet-realtime-eou-120m-coreml`) — the one with a genuine low-latency streaming API.
  Multilingual would mean a different manager/model, not evaluated.
- Model cache lands at `~/Library/Application Support/FluidAudio/Models/parakeet-eou-streaming/`
  (FluidAudio's own default, not `~/Library/Application Support/Pour/`) — worth knowing if
  something needs a clean-slate re-download for testing.

## Next steps

1. Dictate more, varied sentences on Parakeet to actually assess accuracy/latency against Apple
   — only one sentence has been evaluated so far.
2. Decide on the live-preview question above once there's more to go on.
3. Smooth the progress bar (running max) if it's worth polishing.
4. Update `README.md`'s "Included now" / feature list once Parakeet has more real testing behind
   it — deliberately not done yet, since "worked once" isn't "confirmed."
