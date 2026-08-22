# Parakeet engine — in progress, paused here

Started: swapping in a second `SpeechEngine` (Parakeet, via [FluidAudio](https://github.com/FluidInference/FluidAudio))
alongside Apple's SpeechAnalyzer. Paused mid-session because the first live download attempt
surfaced a real concurrency bug (below) that deserves a clear head, not a rushed patch — see
the "don't mess with base functionality" instruction this was built under.

**Current state: safe.** Apple's engine is untouched and confirmed working. The Parakeet path
is wired end-to-end and reachable from Settings, but has not completed a successful model
download in testing yet.

## What's done

- `Sources/ParakeetKit/ParakeetSpeechEngine.swift` — a `SpeechEngine` conformance wrapping
  FluidAudio's `StreamingEouAsrManager` (an actor). Bridges the actor's async API into
  `SpeechEngine`'s synchronous, audio-thread-safe `feed(_:)` the same way `AppleSpeechEngine`
  bridges `SpeechAnalyzer` — buffers queue into an `AsyncStream`, a background `Task` drains it.
- `DictationController.engineFactory` — new injectable property
  (`(Locale, ((Double) -> Void)?) async throws -> any SpeechEngine`), defaulting to Apple's
  engine. This is the whole seam; `FlowCore` still doesn't know Parakeet exists.
- `AppSettings.engineKind: EngineKind` (`.apple` / `.parakeet`), default `.apple`, decoded with
  a fallback so existing users' settings files aren't affected.
- `AppModel.setEngineKind(_:onDownloadProgress:)` — swaps the factory and restarts the
  controller, same pattern as `setLocale`.
- Settings → Model → Engine: a segmented Apple/Parakeet picker. Language picker disables
  itself when Parakeet is selected (English-only for now, via the 120M EOU model).
- `Package.swift` — FluidAudio pinned to `exact: "0.15.6"` (confirmed API-compatible with the
  code above by diffing `main` against the tag before writing anything).

## What's confirmed working

- Everything builds clean, including a full `./build.sh app` release build.
- Apple engine, launched fresh: `Ready · press ` to dictate` — unaffected, verified via the
  status line after every change below.
- Switching Settings → Engine → Parakeet **does** trigger a real download with live progress
  reporting (`FluidAudio`'s `ProgressHandler` → the same `downloadProgress` UI Apple's asset
  download already uses). Watched it move 0% → ~49% in testing.
- A genuinely corrupted download (`weight.bin` empty file) was caught by FluidAudio's own
  validation and surfaced correctly through the existing `.blocked(reason)` state → "Retry
  Setup" flow — the error path works, unchanged from how Apple engine failures already behave.

## What's NOT confirmed

- **A successful end-to-end Parakeet model load.** Two live attempts both hit real problems
  (a corrupted download, then the concurrency bug below) before finishing. Never got to test
  actual transcription quality/latency.
- Whether `StreamingEouAsrManager`'s `setPartialTranscriptCallback` gives usably fast/accurate
  live preview text once actually running.

## Known bug — fix before doing anything else here

**Calling `DictationController.start()` again while a previous `start()` is still awaiting its
engine factory doesn't cancel the first call.** Reproduced: switch Settings → Engine to
Parakeet (kicks off a slow download inside `start()`), then switch back to Apple before the
download finishes. Both `start()` invocations run concurrently:

- Both eventually try to assign `self.engine` / `self.capture` — no ordering guarantee, so
  whichever finishes *last* wins, regardless of which one the user actually asked for last.
- Both `onDownloadProgress` closures stay alive and keep firing — confirmed in testing: the
  Settings UI kept showing "Downloading speech model… 26%" for the *abandoned* Parakeet
  attempt several seconds after switching back to Apple.

This isn't Parakeet-specific — it's latent in `start()`/`updateLocale()` any time one is called
before a prior call resolves, just far more likely to be hit now that an engine's setup can
take much longer than Apple's (which is usually near-instant after the first locale download).

**Fix shape** (not yet implemented): give `DictationController` a generation counter or a
cancellable `Task` for the in-flight `start()`, and have a new call cancel/ignore the stale
one — e.g. store `private var startGeneration = 0`, increment at the top of `start()`, capture
the value, and check it's still current before committing `self.engine`/`self.capture` and
before invoking `onDownloadProgress`. `Task` cancellation alone won't help here since the
FluidAudio download call isn't itself cancellable from what's been seen — a generation check is
the reliable way to just discard the stale result when it eventually arrives.

## Also worth knowing before picking this back up

- **Progress isn't monotonic.** FluidAudio reports progress per-file across several required
  model files (encoder/decoder/joint/tokenizer), so the UI saw it jump around (e.g. 40% → 12%)
  as each new file's download started. Not a bug in the glue code — just don't be alarmed by it,
  and consider smoothing it in the UI (track a running max) once the concurrency fix lands.
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

## Next session checklist

1. Fix the `start()` re-entrancy bug first — it's real and will keep corrupting test results
   otherwise, including for the existing Apple/locale-switch path.
2. Re-attempt the Parakeet download somewhere with a known-stable connection; the one corrupted
   file suggests it may just have been this environment's network, not FluidAudio itself.
3. Once a model loads successfully, actually dictate with it — verify latency, accuracy, and
   whether the partial/preview text is worth showing live or better suppressed until `finish()`.
4. Smooth the progress bar (running max) once (1) is fixed and this is worth polishing.
5. Update `README.md`'s "Included now" / feature list once Parakeet is actually confirmed
   working end-to-end — deliberately not done yet since it isn't.
