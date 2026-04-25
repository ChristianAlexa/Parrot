# Changelog

## [0.6.6](https://github.com/christianalexa/parrot/releases/tag/v0.6.6) — 2026-04-24

### Bug Fixes

- Skip DMG mount dance in CI to avoid runner flakiness
## [0.6.5](https://github.com/christianalexa/parrot/releases/tag/v0.6.5) — 2026-04-24

### Features

- Add baseline WPM picker and GitHub releases link to settings
- Replace idle waveform with compact dot indicator

### Refactoring

- Extract Llama3PromptFormatter from CleanupPrompt

### Testing

- Add Llama3PromptFormatter and delegation tests
## [0.6.4](https://github.com/christianalexa/parrot/releases/tag/v0.6.4) — 2026-04-11

### Bug Fixes

- Skip auto-period for URLs, paths, and code tokens

### Features

- Wire up Launch at Login toggle
## [0.6.3](https://github.com/christianalexa/parrot/releases/tag/v0.6.3) — 2026-04-10

### Bug Fixes

- Harden TextInjector clipboard restore

### Refactoring

- Unify test and normal transcription routing via notifications
## [0.6.2](https://github.com/christianalexa/parrot/releases/tag/v0.6.2) — 2026-04-10

### Bug Fixes

- Resolve main-actor isolation errors in Swift 6 mode
## [0.6.1](https://github.com/christianalexa/parrot/releases/tag/v0.6.1) — 2026-04-10

### Bug Fixes

- Handle audio engine start failures and improve device logging

### Features

- Clearer 2-step accessibility flow in onboarding

### Refactoring

- Thread TonePreset explicitly and drop unused presets
- Introduce ModelsStore as source of truth for model lists
- Centralize UserDefaults keys into DefaultsKey enum
## [0.6.0](https://github.com/christianalexa/parrot/releases/tag/v0.6.0) — 2026-04-08

### Bug Fixes

- Improve reset permission discoverability in onboarding

### Features

- Add floating bar with live waveform during recording
- Add git-cliff for automated release notes

### Refactoring

- Use DateComponentsFormatter for stats and minor cleanups

### Testing

- Add floating bar controller and audio level monitor tests
## [0.5.0](https://github.com/christianalexa/parrot/releases/tag/v0.5.0) — 2026-04-08

### Bug Fixes

- Strip leading dashes from Whisper transcription output

### Features

- Add personal dictionary export/import with merge support
- Add post-processing for neutral/professional/technical tones
## [0.4.1](https://github.com/christianalexa/parrot/releases/tag/v0.4.1) — 2026-04-04

### Bug Fixes

- DMG creation works headless on CI runners
## [0.4.0](https://github.com/christianalexa/parrot/releases/tag/v0.4.0) — 2026-04-04

### Bug Fixes

- Apply tone postProcess regardless of LLM state

### Features

- Gate releases on tests and add CI workflow
- Add comprehensive test suite (95 tests)
## [0.3.9](https://github.com/christianalexa/parrot/releases/tag/v0.3.9) — 2026-04-04

### Bug Fixes

- Hotkey recordings always inject into focused app

### Miscellaneous

- Tighten DMG README
## [0.3.8](https://github.com/christianalexa/parrot/releases/tag/v0.3.8) — 2026-04-04

### Reverted

- Remove Setup.command from DMG
## [0.3.7](https://github.com/christianalexa/parrot/releases/tag/v0.3.7) — 2026-04-04

### Features

- Add Setup.command to DMG for quarantine removal
## [0.3.6](https://github.com/christianalexa/parrot/releases/tag/v0.3.6) — 2026-04-04

### Bug Fixes

- Improve setup flow permission handling and UX

### Refactoring

- Make start builds proper .app bundle for dev
- Replace Setup applet with standard drag-to-install DMG
## [0.3.5](https://github.com/christianalexa/parrot/releases/tag/v0.3.5) — 2026-04-04

### Bug Fixes

- Only reset accessibility TCC on fresh installs
- Route test mode transcription to notification instead of injecting

### Features

- Redesign DMG installer with native Setup applet

### Miscellaneous

- Remove zip from release workflow uploads
- Remove zip artifact from release target
## [0.3.4](https://github.com/christianalexa/parrot/releases/tag/v0.3.4) — 2026-04-04

### Bug Fixes

- Reset test recording flag on status change
- Replace sleep with inference lock in LlamaManager
- Await recording task before processing on stop
- Guard model selection against missing files

### Features

- Add ready step to setup flow with relaunch prompt
## [0.3.3](https://github.com/christianalexa/parrot/releases/tag/v0.3.3) — 2026-04-04

### Bug Fixes

- Reset stale accessibility grant during setup flow

### Features

- Add DMG installer to release target
## [0.3.2](https://github.com/christianalexa/parrot/releases/tag/v0.3.2) — 2026-04-04

### Bug Fixes

- Resolve strict concurrency error in setup completion observer
- Prevent test mode from hijacking global hotkey recording

### Features

- Add first-run setup flow for permissions and model download
## [0.3.1](https://github.com/christianalexa/parrot/releases/tag/v0.3.1) — 2026-04-01

### Bug Fixes

- Extract tag annotation directly to avoid commit message leak
- Use tag body only for release notes, exclude commit message

### Features

- Replace auto idle unload with manual model unload/load button
- Add `make tag` for streamlined release tagging
## [0.3.0](https://github.com/christianalexa/parrot/releases/tag/v0.3.0) — 2026-04-01

### Documentation

- Add tccutil troubleshooting for accessibility prompt after updates

### Features

- Use annotated tag messages as release notes
- Unload models after 5 min idle to reclaim ~2 GB memory
## [0.2.0](https://github.com/christianalexa/parrot/releases/tag/v0.2.0) — 2026-03-29

### Bug Fixes

- Grant contents write permission to release workflow
- Add @MainActor to MenuBarContentView for CI concurrency check
- Resolve strict concurrency errors for CI builds
- Surface hotkey failure in UI and add troubleshooting docs

### Documentation

- Add NOTICE, privacy policy, and model license documentation
- Add Apache 2.0 license
- Add parrot image to README

### Features

- Add `make check` for pre-push release build validation
- Add stats tab with usage tracking
- Add GitHub Actions release workflow
## [0.1.0](https://github.com/christianalexa/parrot/releases/tag/v0.1.0) — 2026-03-28

### Features

- Initial commit — Parrot macOS menu bar transcription app
