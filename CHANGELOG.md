# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1](https://github.com/zeeetech/ekko/compare/v0.1.0...v0.1.1) (2026-04-13)


### Continuous Integration

* focus on elixir 1.18 and 1.19 ([31e716d](https://github.com/zeeetech/ekko/commit/31e716d482ded5170a2a8fe1804298311beeb470))

## [0.1.0] - 2026-04-10

### Added

- `Ekko` — request context and response builder (speech, cards, directives, session control)
- `Ekko.Skill` — behaviour with `handle_request/2`, `before_request/1`, `after_request/2`, `handle_error/3` lifecycle
- `Ekko.Request` — parser for all Alexa request types:
  - `LaunchRequest`, `IntentRequest`, `SessionEndedRequest`
  - `AudioPlayer.PlaybackStarted/Finished/Stopped/NearlyFinished/Failed`
  - `PlaybackController.Play/Pause/Next/Previous/ResumeCommandIssued`
  - `System.ExceptionEncountered`
- `Ekko.Plug` — mountable Plug adapter with automatic request verification
- `Ekko.Verifier` — behaviour with `Default` (5-step Amazon verification pipeline) and `NoOp` implementations
- `Ekko.Crypto.CertCache` — ETS-backed certificate chain cache with configurable TTL
- `Ekko.Crypto.CertValidator` — URL structure and X.509 chain validation
- `Ekko.Crypto.SignatureVerifier` — RSA-SHA256 body signature verification
- `Ekko.AudioPlayer` — high-level helpers for building AudioPlayer responses from playlists
- `Ekko.AudioPlayer.Playlist` — pure-data playlist with cursor, shuffle, and loop support
- `Ekko.AudioPlayer.PlaylistStore` — behaviour for playlist persistence with default ETS adapter
- Response constraint enforcement — `AudioPlayer.*` and `PlaybackController.*` handlers cannot return `outputSpeech`, `card`, or `reprompt`
- `Ekko.Test.RequestFixtures` — decoded-JSON request fixtures for SDK consumers
